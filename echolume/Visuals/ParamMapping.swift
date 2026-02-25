//
//  ParamMapping.swift
//  echolume
//
//  Converts analyzer snapshot + abstraction + theme + seed into VisualParams.
//  Smoothing and nonlinear curves for stable, musical visuals.
//

import Foundation
import simd

/// Input snapshot from analyzer (thread-safe copy).
struct AnalyzerSnapshot {
    var level: Float
    var peak: Float
    var low: Float
    var mid: Float
    var high: Float
}

/// Maps analyzer + user settings to VisualParams. Holds internal smoothers (use from one thread only).
final class ParamMapping {
    private let levelSmooth = SmoothValue(initial: 0, attackCoeff: 0.25, releaseCoeff: 0.02)
    private let peakSmooth = SmoothValue(initial: 0, attackCoeff: 0.5, releaseCoeff: 0.1)
    private let lowSmooth = SmoothValue(initial: 0, attackCoeff: 0.2, releaseCoeff: 0.03)
    private let midSmooth = SmoothValue(initial: 0, attackCoeff: 0.25, releaseCoeff: 0.03)
    private let highSmooth = SmoothValue(initial: 0, attackCoeff: 0.35, releaseCoeff: 0.02)
    private let warpSmooth = SmoothValue(initial: 0, attackCoeff: 0.2, releaseCoeff: 0.05)
    private let trailSmooth = SmoothValue(initial: 0, attackCoeff: 0.15, releaseCoeff: 0.04)

    /// Produce VisualParams from current snapshot and settings. Call from render thread.
    func map(
        snapshot: AnalyzerSnapshot,
        abstraction: Float,
        theme: Theme,
        seed: UInt32,
        time: Float,
        resolution: SIMD2<Float>
    ) -> VisualParams {
        let level = levelSmooth.tick(with: snapshot.level)
        let peak = peakSmooth.tick(with: snapshot.peak)
        let low = lowSmooth.tick(with: curve(snapshot.low))
        let mid = midSmooth.tick(with: curve(snapshot.mid))
        let high = highSmooth.tick(with: curve(snapshot.high))
        let absClamp = max(0, min(1, abstraction))
        let warpAmount = warpSmooth.tick(with: low * 0.5 + mid * 0.3 + absClamp * 0.4)
        let trailPersistence = trailSmooth.tick(with: 0.3 + low * 0.4 + absClamp * 0.3)

        let pal = theme.nudgedPalette(seed: seed)
        let p0 = pal.count > 0 ? pal[0] : SIMD4<Float>(0.2, 0.2, 0.3, 1)
        let p1 = pal.count > 1 ? pal[1] : p0
        let p2 = pal.count > 2 ? pal[2] : p1
        let p3 = pal.count > 3 ? pal[3] : p2
        let p4 = pal.count > 4 ? pal[4] : p3

        return VisualParams(
            time: time,
            resolution: resolution,
            level: level,
            peak: min(1, peak),
            low: low,
            mid: mid,
            high: high,
            abstraction: absClamp,
            seed: seed,
            themeID: theme.id,
            palette: (p0, p1, p2, p3, p4),
            warpAmount: warpAmount,
            trailPersistence: trailPersistence
        )
    }

    /// Soft curve to reduce jitter and feel more musical.
    private func curve(_ x: Float) -> Float {
        let c = max(0, min(1, x))
        return c * c * (3 - 2 * c)
    }
}
