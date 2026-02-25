//
//  VisualParams.swift
//  echolume
//

import simd

/// Normalized params passed to the renderer each frame. Layout must match Metal uniform struct.
struct VisualParams {
    var time: Float
    var resolution: SIMD2<Float>
    var level: Float      // rms 0…1
    var peak: Float       // 0…1
    var low: Float        // low band 0…1
    var mid: Float
    var high: Float
    var abstraction: Float
    var seed: UInt32
    var themeID: UInt32
    /// 3–5 colors as RGBA float; pad to 5 for fixed Metal layout.
    var palette: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)
    /// Derived for shader: warp amount, trail persistence, etc.
    var warpAmount: Float
    var trailPersistence: Float
}
