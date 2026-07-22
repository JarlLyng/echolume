//
//  Renderer.swift
//  echolume
//

import AppKit
import Metal
import MetalKit
import simd

/// Must match Metal Uniforms layout (including padding for float4 alignment).
struct ShaderUniforms {
    var time: Float
    var resolution: SIMD2<Float>
    var level: Float
    var peak: Float
    var low: Float
    var mid: Float
    var high: Float
    var abstraction: Float
    var seed: UInt32
    var themeID: UInt32
    var _pad: Float = 0
    var palette0: SIMD4<Float>
    var palette1: SIMD4<Float>
    var palette2: SIMD4<Float>
    var palette3: SIMD4<Float>
    var palette4: SIMD4<Float>
    var warpAmount: Float
    var trailPersistence: Float
    var shapeStyleIndex: Int32
    var shapeCount: Float
    var noiseStrength: Float
    var motionSpeed: Float
    var reactivity: Float
    var impact: Float
    var impulse: Float
    var sceneType: Int32
    var motion: Float
    var noise: Float
    var glitch: Float
    var lfo1: Float
    var lfo2: Float
    var lfo3: Float
    var speedMul: Float
    var glitchPhase: Float
    var beatPhase: Float
    var bpm: Float
}

final class Renderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState   // single-pass fallback
    private var feedbackPipeline: MTLRenderPipelineState
    private var presentPipeline: MTLRenderPipelineState
    private let sampler: MTLSamplerState
    private var vertexBuffer: MTLBuffer
    /// kSpectrumBins floats, refilled each frame from the provider and bound at
    /// fragment buffer index 1 for spectrum-style scenes.
    private let spectrumBuffer: MTLBuffer

    /// kSpectrumHistoryRows × kSpectrumBins floats bound at fragment buffer
    /// index 2 for scrolling-terrain scenes (ridgeline). Row 0 is the newest
    /// spectrum; rows scroll back in time. The CPU-side ring avoids reordering
    /// the GPU copy except when a new row lands.
    private let historyBuffer: MTLBuffer
    private var historyRing = [Float](repeating: 0, count: kSpectrumHistoryRows * kSpectrumBins)
    private var historyHead = 0
    private var historyAccum: Float = 0
    private var lastHistoryTime: Float = -1
    private let startTime = CACurrentMediaTime()
    private weak var paramsProvider: VisualParamsProvider?

    /// Beat phase advanced at render rate (60 fps) from the detected BPM and
    /// softly corrected toward the analysis-thread phase (which updates ~23 Hz).
    private var displayBeatPhase: Float = 0
    private var prevBeatTime: Float = -1

    /// Active Live recording (nil when not recording). Owned by the render
    /// thread; started/stopped by polling the provider's recording flag.
    private var recorder: VideoRecorder?
    /// Finalizes an active recording on app termination (deinit is NOT
    /// guaranteed on quit, and an unfinalized .mp4 has no moov atom — the
    /// whole capture would be lost if the performer hits Cmd-Q mid-recording).
    private var terminationObserver: (any NSObjectProtocol)?

    deinit {
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
        // Finalize a recording if the view is torn down mid-capture, so the
        // file on disk is playable rather than truncated.
        if let recorder {
            recorder.finish { url, error in
                var info: [String: Any] = [:]
                if let url { info["url"] = url }
                if let error { info["error"] = error }
                NotificationCenter.default.post(name: .echolumeRecordingFinished, object: nil, userInfo: info)
            }
        }
    }

    /// Ping-pong accumulation textures for the feedback/trail pass.
    private var accum: [MTLTexture] = []
    private var accumIndex = 0
    private var accumSize: SIMD2<Int> = .zero
    private var clearPending = true
    private static let accumFormat: MTLPixelFormat = .rgba16Float

    init?(metalDevice device: MTLDevice, paramsProvider: VisualParamsProvider) {
        self.device = device
        self.paramsProvider = paramsProvider
        guard let queue = device.makeCommandQueue() else { return nil }
        commandQueue = queue

        let quadVertices: [Float] = [
            -1, -1, 1, -1, -1, 1,
            -1, 1, 1, -1, 1, 1
        ]
        let size = quadVertices.count * MemoryLayout<Float>.stride
        guard let buf = device.makeBuffer(bytes: quadVertices, length: size, options: .storageModeShared) else {
            return nil
        }
        vertexBuffer = buf

        guard let specBuf = device.makeBuffer(length: kSpectrumBins * MemoryLayout<Float>.stride, options: .storageModeShared) else {
            return nil
        }
        spectrumBuffer = specBuf

        guard let histBuf = device.makeBuffer(length: kSpectrumHistoryRows * kSpectrumBins * MemoryLayout<Float>.stride, options: .storageModeShared) else {
            return nil
        }
        historyBuffer = histBuf

        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "fullscreenQuadVertex"),
              let fragmentFunction = library.makeFunction(name: "fullscreenQuadFragment") else {
            return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        guard let feedbackFn = library.makeFunction(name: "feedbackFragment"),
              let presentFn = library.makeFunction(name: "presentFragment") else {
            return nil
        }

        let feedbackDesc = MTLRenderPipelineDescriptor()
        feedbackDesc.vertexFunction = vertexFunction
        feedbackDesc.fragmentFunction = feedbackFn
        feedbackDesc.colorAttachments[0].pixelFormat = Self.accumFormat

        let presentDesc = MTLRenderPipelineDescriptor()
        presentDesc.vertexFunction = vertexFunction
        presentDesc.fragmentFunction = presentFn
        presentDesc.colorAttachments[0].pixelFormat = .bgra8Unorm

        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.minFilter = .linear
        samplerDesc.magFilter = .linear
        samplerDesc.sAddressMode = .clampToEdge
        samplerDesc.tAddressMode = .clampToEdge
        guard let samplerState = device.makeSamplerState(descriptor: samplerDesc) else { return nil }
        sampler = samplerState

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            feedbackPipeline = try device.makeRenderPipelineState(descriptor: feedbackDesc)
            presentPipeline = try device.makeRenderPipelineState(descriptor: presentDesc)
        } catch {
            Log.error("[Renderer] Pipeline state creation failed: \(error.localizedDescription)")
            return nil
        }

        super.init()

        // Cmd-Q with a recording running must not lose the file: block the
        // main thread briefly while the writer finalizes the moov atom.
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.finishRecordingBlocking()
        }
    }

    /// Finalize an active recording synchronously (bounded wait). Called on
    /// the main thread during app termination.
    private func finishRecordingBlocking() {
        guard let active = recorder else { return }
        recorder = nil
        let done = DispatchSemaphore(value: 0)
        active.finish { url, error in
            var info: [String: Any] = [:]
            if let url { info["url"] = url }
            if let error { info["error"] = error }
            NotificationCenter.default.post(name: .echolumeRecordingFinished, object: nil, userInfo: info)
            done.signal()
        }
        _ = done.wait(timeout: .now() + 2.0)
    }

    func draw(in view: MTKView) {
        guard let provider = paramsProvider,
              let drawable = view.currentDrawable,
              let drawableDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        let t = Float(CACurrentMediaTime() - startTime)
        let res = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
        let p = provider.params(time: t, resolution: res)

        // Advance beat phase smoothly at render rate; nudge toward the tracked
        // phase so it stays locked without stepping at the slower analysis rate.
        let beatDt = prevBeatTime < 0 ? 0 : max(0, t - prevBeatTime)
        prevBeatTime = t
        if p.bpm > 0 {
            displayBeatPhase = Self.fract(displayBeatPhase + beatDt * p.bpm / 60)
            let err = p.beatPhase - displayBeatPhase
            displayBeatPhase = Self.fract(displayBeatPhase + 0.05 * (err - (err).rounded()))
        } else {
            displayBeatPhase = 0
        }

        let pal = p.palette
        var uniforms = ShaderUniforms(
            time: p.time,
            resolution: p.resolution,
            level: p.level,
            peak: p.peak,
            low: p.low,
            mid: p.mid,
            high: p.high,
            abstraction: p.abstraction,
            seed: p.seed,
            themeID: p.themeID,
            _pad: 0,
            palette0: pal.0,
            palette1: pal.1,
            palette2: pal.2,
            palette3: pal.3,
            palette4: pal.4,
            warpAmount: p.warpAmount,
            trailPersistence: p.trailPersistence,
            shapeStyleIndex: Int32(p.shapeStyleIndex),
            shapeCount: p.shapeCount,
            noiseStrength: p.noiseStrength,
            motionSpeed: p.motionSpeed,
            reactivity: p.reactivity,
            impact: p.impact,
            impulse: p.impulse,
            sceneType: Int32(p.sceneType),
            motion: p.motion,
            noise: p.noise,
            glitch: p.glitch,
            lfo1: p.lfo1,
            lfo2: p.lfo2,
            lfo3: p.lfo3,
            speedMul: p.speedMul,
            glitchPhase: p.glitchPhase,
            beatPhase: displayBeatPhase,
            bpm: p.bpm
        )

        // Refill the spectrum buffer from the analyzer for spectrum-style scenes.
        provider.copySpectrum(into: spectrumBuffer.contents().assumingMemoryBound(to: Float.self))

        // Advance the spectrum history for scrolling-terrain scenes. The Motion
        // knob sets how fast the terrain scrolls away.
        updateSpectrumHistory(time: p.time, motion: p.motion)

        // Panic Reset clears the trails.
        if provider.consumeTrailReset() { clearPending = true }

        ensureAccumTextures(width: Int(view.drawableSize.width), height: Int(view.drawableSize.height))

        // Fallback to a single direct pass if accumulation textures are unavailable.
        guard accum.count == 2 else {
            if let enc = commandBuffer.makeRenderCommandEncoder(descriptor: drawableDescriptor) {
                enc.setRenderPipelineState(pipelineState)
                enc.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                enc.setFragmentBytes(&uniforms, length: MemoryLayout<ShaderUniforms>.stride, index: 0)
                enc.setFragmentBuffer(spectrumBuffer, offset: 0, index: 1)
                enc.setFragmentBuffer(historyBuffer, offset: 0, index: 2)
                enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                enc.endEncoding()
            }
            commandBuffer.present(drawable)
            commandBuffer.commit()
            return
        }

        let prev = accum[accumIndex]
        let curr = accum[1 - accumIndex]

        if clearPending {
            let clearedPrev = clear(prev, commandBuffer: commandBuffer)
            let clearedCurr = clear(curr, commandBuffer: commandBuffer)
            // Only consider it done if both clears actually encoded; otherwise
            // keep it pending so the next frame retries (no stale trails).
            if clearedPrev && clearedCurr { clearPending = false }
        }

        // Pass 1: scene blended over decayed previous frame → curr.
        let p1 = MTLRenderPassDescriptor()
        p1.colorAttachments[0].texture = curr
        p1.colorAttachments[0].loadAction = .dontCare
        p1.colorAttachments[0].storeAction = .store
        if let enc = commandBuffer.makeRenderCommandEncoder(descriptor: p1) {
            enc.setRenderPipelineState(feedbackPipeline)
            enc.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            enc.setFragmentBytes(&uniforms, length: MemoryLayout<ShaderUniforms>.stride, index: 0)
            enc.setFragmentBuffer(spectrumBuffer, offset: 0, index: 1)
            enc.setFragmentBuffer(historyBuffer, offset: 0, index: 2)
            enc.setFragmentTexture(prev, index: 0)
            enc.setFragmentSamplerState(sampler, index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            enc.endEncoding()
        }

        // Pass 2: present curr → drawable.
        if let enc = commandBuffer.makeRenderCommandEncoder(descriptor: drawableDescriptor) {
            enc.setRenderPipelineState(presentPipeline)
            enc.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            enc.setFragmentTexture(curr, index: 0)
            enc.setFragmentSamplerState(sampler, index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            enc.endEncoding()
        }

        // Pass 3 (recording only): the same present pass into a
        // CVPixelBuffer-backed texture, appended to the writer once the GPU
        // finishes the frame. See updateRecording() for start/stop.
        updateRecording(source: curr, drawableSize: view.drawableSize, commandBuffer: commandBuffer)

        accumIndex = 1 - accumIndex
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        ensureAccumTextures(width: Int(size.width), height: Int(size.height))
    }

    /// Start/stop/feed the Live recording based on the provider flag. Runs on
    /// the render thread once per frame, after the present pass is encoded.
    private func updateRecording(source: MTLTexture, drawableSize: CGSize, commandBuffer: MTLCommandBuffer) {
        let wantsRecording = paramsProvider?.isRecordingEnabled() ?? false

        if let active = recorder {
            // Stop on request, or if the surface was resized (the writer's
            // dimensions are fixed at start).
            let resized = abs(active.size.width - drawableSize.width) > 2 || abs(active.size.height - drawableSize.height) > 2
            if !wantsRecording || resized {
                finishRecorder(active, stoppedBySizeChange: resized && wantsRecording)
                recorder = nil
            }
        }

        if wantsRecording && recorder == nil {
            let url = VideoRecorder.defaultDestination()
            recorder = VideoRecorder(device: device, size: drawableSize, url: url)
            if recorder == nil {
                Log.error("[Recorder] Could not start recording (writer init failed)")
                paramsProvider?.setRecordingEnabled(false)
                NotificationCenter.default.post(
                    name: .echolumeRecordingFinished, object: nil,
                    userInfo: ["error": "Could not start recording"]
                )
            }
        }

        guard let recorder, let (pixelBuffer, target) = recorder.makeFrameTarget() else { return }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        if let enc = commandBuffer.makeRenderCommandEncoder(descriptor: pass) {
            enc.setRenderPipelineState(presentPipeline)
            enc.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            enc.setFragmentTexture(source, index: 0)
            enc.setFragmentSamplerState(sampler, index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            enc.endEncoding()
        }
        let hostTime = CACurrentMediaTime()
        commandBuffer.addCompletedHandler { _ in
            recorder.commit(pixelBuffer: pixelBuffer, at: hostTime)
        }
    }

    /// Finalize a recording and tell the UI how it went.
    private func finishRecorder(_ recorder: VideoRecorder, stoppedBySizeChange: Bool) {
        recorder.finish { url, error in
            var info: [String: Any] = [:]
            if let url { info["url"] = url }
            if let error { info["error"] = error }
            if stoppedBySizeChange { info["sizeChanged"] = true }
            NotificationCenter.default.post(name: .echolumeRecordingFinished, object: nil, userInfo: info)
        }
        if stoppedBySizeChange {
            paramsProvider?.setRecordingEnabled(false)
        }
    }

    /// Push the current spectrum into the history ring at a rate set by the
    /// Motion knob (slow terrain at 0, fast scroll at 1), then mirror the ring
    /// into the GPU buffer ordered newest-first. Called once per frame from
    /// draw(); ~12 KB of copies at most, only when a row actually advances.
    private func updateSpectrumHistory(time: Float, motion: Float) {
        let dt = lastHistoryTime < 0 ? 0 : min(max(time - lastHistoryTime, 0), 0.1)
        lastHistoryTime = time
        historyAccum += dt * (8 + 40 * max(0, min(1, motion)))
        guard historyAccum >= 1 else { return }

        let spec = spectrumBuffer.contents().assumingMemoryBound(to: Float.self)
        while historyAccum >= 1 {
            historyAccum -= 1
            let base = historyHead * kSpectrumBins
            for i in 0 ..< kSpectrumBins { historyRing[base + i] = spec[i] }
            historyHead = (historyHead + 1) % kSpectrumHistoryRows
        }

        let dst = historyBuffer.contents().assumingMemoryBound(to: Float.self)
        for row in 0 ..< kSpectrumHistoryRows {
            let src = ((historyHead - 1 - row) % kSpectrumHistoryRows + kSpectrumHistoryRows) % kSpectrumHistoryRows
            let s = src * kSpectrumBins
            let d = row * kSpectrumBins
            for i in 0 ..< kSpectrumBins { dst[d + i] = historyRing[s + i] }
        }
    }

    /// Clear the trails on the next frame (panic reset / size change).
    func resetFeedback() { clearPending = true }

    /// (Re)create the ping-pong accumulation textures when missing or resized.
    private func ensureAccumTextures(width: Int, height: Int) {
        guard width > 0, height > 0 else { return }
        if accum.count == 2, accumSize == SIMD2(width, height) { return }
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: Self.accumFormat, width: width, height: height, mipmapped: false)
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .private
        guard let a = device.makeTexture(descriptor: desc),
              let b = device.makeTexture(descriptor: desc) else {
            accum = []
            return
        }
        accum = [a, b]
        accumSize = SIMD2(width, height)
        accumIndex = 0
        clearPending = true
    }

    /// Returns false if the clear encoder couldn't be created, so the caller
    /// can keep `clearPending` set and retry next frame instead of leaving
    /// stale trails behind.
    @discardableResult
    private func clear(_ texture: MTLTexture, commandBuffer: MTLCommandBuffer) -> Bool {
        let d = MTLRenderPassDescriptor()
        d.colorAttachments[0].texture = texture
        d.colorAttachments[0].loadAction = .clear
        d.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        d.colorAttachments[0].storeAction = .store
        guard let enc = commandBuffer.makeRenderCommandEncoder(descriptor: d) else { return false }
        enc.endEncoding()
        return true
    }

    /// Fractional part in 0..<1 (handles negatives).
    private static func fract(_ x: Float) -> Float {
        let v = x - x.rounded(.down)
        return v < 0 ? v + 1 : v
    }
}
