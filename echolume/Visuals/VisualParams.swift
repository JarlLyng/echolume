//
//  VisualParams.swift
//  echolume
//

import simd

/// Normalized params passed to the renderer each frame. Layout must match Metal uniform struct.
struct VisualParams {
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
    var palette: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)
    var warpAmount: Float
    var trailPersistence: Float
    var shapeStyleIndex: Int
    var shapeCount: Float
    var noiseStrength: Float
    var motionSpeed: Float
    var reactivity: Float
    var smoothedLow: Float
    var smoothedMid: Float
    var smoothedHigh: Float
    var impact: Float
    var impulse: Float
    var sceneType: Int
    var motion: Float
    var noise: Float
    var glitch: Float
    var lfo1: Float
    var lfo2: Float
    var lfo3: Float
    var speedMul: Float
    var glitchPhase: Float
}
