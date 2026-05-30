//
//  Renderer.swift
//  echolume
//

import Metal
import MetalKit
import Sentry
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
    private var pipelineState: MTLRenderPipelineState
    private var vertexBuffer: MTLBuffer
    private let startTime = CACurrentMediaTime()
    private weak var paramsProvider: VisualParamsProvider?

    /// Beat phase advanced at render rate (60 fps) from the detected BPM and
    /// softly corrected toward the analysis-thread phase (which updates ~23 Hz).
    private var displayBeatPhase: Float = 0
    private var prevBeatTime: Float = -1

    init?(metalDevice device: MTLDevice, paramsProvider: VisualParamsProvider) {
        self.device = device
        self.paramsProvider = paramsProvider
        guard let queue = device.makeCommandQueue() else { return nil }
        commandQueue = queue

        let quadVertices: [Float] = [
            -1, -1,  1, -1, -1,  1,
            -1,  1,  1, -1,  1,  1
        ]
        let size = quadVertices.count * MemoryLayout<Float>.stride
        guard let buf = device.makeBuffer(bytes: quadVertices, length: size, options: .storageModeShared) else {
            return nil
        }
        vertexBuffer = buf

        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "fullscreenQuadVertex"),
              let fragmentFunction = library.makeFunction(name: "fullscreenQuadFragment") else {
            return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            SentrySDK.capture(error: error) { scope in
                scope.setTag(value: "render_pipeline", key: "failure_point")
            }
            return nil
        }

        super.init()
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor),
              let provider = paramsProvider else {
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

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<ShaderUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    /// Reset any internal feedback/trail state. No-op when renderer is stateless (for panic reset).
    func resetFeedback() {}

    /// Fractional part in 0..<1 (handles negatives).
    private static func fract(_ x: Float) -> Float {
        let v = x - x.rounded(.down)
        return v < 0 ? v + 1 : v
    }
}
