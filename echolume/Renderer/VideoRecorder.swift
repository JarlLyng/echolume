//
//  VideoRecorder.swift
//  echolume
//
//  Records the Live output to an .mp4 (H.264, video-only). Zero-copy path:
//  the renderer draws its present pass straight into CVPixelBuffer-backed
//  Metal textures (via CVMetalTextureCache), and frames are appended to the
//  AVAssetWriter on a serial queue after each command buffer completes — the
//  render thread never blocks on the writer.
//

import AVFoundation
import CoreVideo
import Foundation
import Metal

extension Notification.Name {
    /// Posted when a recording ends. userInfo: ["url": URL] on success,
    /// ["error": String] on failure.
    static let echolumeRecordingFinished = Notification.Name("echolume.recordingFinished")
}

final class VideoRecorder {
    let size: CGSize
    let url: URL

    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private var textureCache: CVMetalTextureCache?
    private let queue = DispatchQueue(label: "echolume.recorder", qos: .userInitiated)
    private var firstFrameTime: CFTimeInterval = -1
    private var finishing = false

    /// Where recordings land: the real ~/Movies (the sandbox HOME is the
    /// container, so resolve the actual home via getpwuid).
    static func defaultDestination() -> URL {
        let realHome: URL
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            realHome = URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        } else {
            realHome = FileManager.default.homeDirectoryForCurrentUser
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let name = "Echolume Recording \(formatter.string(from: Date())).mp4"
        return realHome.appendingPathComponent("Movies", isDirectory: true).appendingPathComponent(name)
    }

    init?(device: MTLDevice, size: CGSize, url: URL) {
        guard size.width >= 2, size.height >= 2 else { return nil }
        // H.264 requires even dimensions.
        let width = Int(size.width) & ~1
        let height = Int(size.height) & ~1
        self.size = CGSize(width: width, height: height)
        self.url = url

        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else {
            Log.error("[Recorder] Could not create writer at \(url.path)")
            return nil
        }
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: min(50_000_000, width * height * 8),
                AVVideoExpectedSourceFrameRateKey: 60,
            ],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else { return nil }
        writer.add(input)

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferMetalCompatibilityKey as String: true,
            ]
        )

        guard writer.startWriting() else {
            Log.error("[Recorder] startWriting failed: \(writer.error?.localizedDescription ?? "unknown")")
            return nil
        }
        writer.startSession(atSourceTime: .zero)

        self.writer = writer
        self.input = input
        self.adaptor = adaptor

        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
        guard cache != nil else { return nil }
        textureCache = cache
    }

    /// A frame the renderer can draw into: a pool-backed pixel buffer, its
    /// Metal texture, and the CVMetalTexture wrapper that OWNS that texture's
    /// backing. The caller MUST keep `cvTexture` alive until the command buffer
    /// that renders into `texture` completes — releasing it earlier frees the
    /// texture memory out from under the GPU (an intermittent crash / garbage
    /// frames). Returns nil under pool pressure (frame skipped).
    struct FrameTarget {
        let pixelBuffer: CVPixelBuffer
        let cvTexture: CVMetalTexture
        let texture: MTLTexture
    }

    func makeFrameTarget() -> FrameTarget? {
        guard !finishing, let pool = adaptor.pixelBufferPool, let cache = textureCache else { return nil }
        var pb: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pb) == kCVReturnSuccess,
              let pixelBuffer = pb else { return nil }
        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, cache, pixelBuffer, nil,
            .bgra8Unorm, Int(size.width), Int(size.height), 0, &cvTexture
        )
        guard status == kCVReturnSuccess, let cvTex = cvTexture, let texture = CVMetalTextureGetTexture(cvTex) else {
            return nil
        }
        return FrameTarget(pixelBuffer: pixelBuffer, cvTexture: cvTex, texture: texture)
    }

    /// Append a rendered frame. Call after the command buffer that drew into
    /// the pixel buffer has completed (any thread; hops to the writer queue).
    func commit(pixelBuffer: CVPixelBuffer, at hostTime: CFTimeInterval) {
        queue.async { [self] in
            guard !finishing, input.isReadyForMoreMediaData, writer.status == .writing else { return }
            if firstFrameTime < 0 { firstFrameTime = hostTime }
            let pts = CMTime(seconds: hostTime - firstFrameTime, preferredTimescale: 60_000)
            adaptor.append(pixelBuffer, withPresentationTime: pts)
        }
    }

    /// Finalize the file. The completion runs on the writer queue with either
    /// the finished file's URL or an error message.
    func finish(completion: @escaping (URL?, String?) -> Void) {
        queue.async { [self] in
            guard !finishing else { return }
            finishing = true
            guard writer.status == .writing else {
                completion(nil, writer.error?.localizedDescription ?? "Recording failed")
                return
            }
            input.markAsFinished()
            writer.finishWriting { [self] in
                if writer.status == .completed {
                    completion(url, nil)
                } else {
                    completion(nil, writer.error?.localizedDescription ?? "Recording failed")
                }
            }
        }
    }
}
