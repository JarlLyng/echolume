//
//  Theme.swift
//  echolume
//

import simd

/// Theme: name + palette (3–5 colors) + base motion settings.
struct Theme: Identifiable {
    let id: UInt32
    let name: String
    /// 3–5 colors RGBA (0…1).
    let palette: [SIMD4<Float>]
    /// Base motion speed (0…1).
    var baseSpeed: Float
    /// Rotation speed multiplier.
    var rotationSpeed: Float

    init(id: UInt32, name: String, palette: [SIMD4<Float>], baseSpeed: Float = 0.3, rotationSpeed: Float = 0.2) {
        self.id = id
        self.name = name
        self.palette = palette
        self.baseSpeed = baseSpeed
        self.rotationSpeed = rotationSpeed
    }

    /// Nudge palette within theme (e.g. for Randomize): slight hue/saturation shift.
    func nudgedPalette(seed: UInt32) -> [SIMD4<Float>] {
        let t = Float(seed % 1000) / 1000
        return palette.map { c in
            let hueShift = (t - 0.5) * 0.05
            var r = c.x, g = c.y, b = c.z
            // Simple RGB nudge
            r = max(0, min(1, r + (t - 0.5) * 0.03))
            g = max(0, min(1, g + (t * 0.02 - 0.01)))
            b = max(0, min(1, b + ((1 - t) * 0.02 - 0.01)))
            return SIMD4<Float>(r, g, b, c.w)
        }
    }
}
