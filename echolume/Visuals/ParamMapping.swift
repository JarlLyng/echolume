//
//  ParamMapping.swift
//  echolume
//
//  Converts analyzer snapshot + abstraction + energyBias + theme + seed into VisualParams.
//  Deterministic abstraction mapping; reactivity from energyBias (low vs high band).
//

import Foundation
import simd

/// Input snapshot from analyzer (thread-safe copy). low/mid/high are envelope-smoothed.
struct AnalyzerSnapshot {
    var level: Float
    var peak: Float
    var low: Float
    var mid: Float
    var high: Float
    var impact: Float
}

private let kPeakImpulseThreshold: Float = 0.7
private let kImpulseDecay: Float = 0.8
private let kGlitchImpulseThreshold: Float = 0.6
private let kGlitchDecay: Float = 0.85

/// Deterministic 0...1 from floor(time*4) and seed for glitch trigger.
private func detRandGlitch(seed: UInt32, time: Float) -> Float {
    let bucket = Int(floor(time * 4))
    let t = Float(bucket & 0x7FFF) + Float(seed % 1000) * 0.001
    return (sin(t * 12.9898 + Float(seed) * 78.233) * 0.5 + 0.5)
}

/// Maps analyzer + user settings to VisualParams. LFOs for baseline motion; glitch events from impulse.
/// No allocations in map(). Single-thread use.
final class ParamMapping {
    private let levelSmooth = SmoothValue(initial: 0, attackCoeff: 0.25, releaseCoeff: 0.02)
    private let peakSmooth = SmoothValue(initial: 0, attackCoeff: 0.5, releaseCoeff: 0.1)
    private var prevPeak: Float = 0
    private var impulse: Float = 0
    private var glitchPhase: Float = 0

    /// Produce VisualParams from current snapshot and settings. Call from render thread.
    func map(
        snapshot: AnalyzerSnapshot,
        abstraction: Float,
        energyBias: Float,
        theme: Theme,
        seed: UInt32,
        shapeStyleIndex: Int,
        sceneTypeIndex: Int,
        time: Float,
        resolution: SIMD2<Float>,
        motion: Float,
        noise: Float,
        glitch: Float
    ) -> VisualParams {
        let level = levelSmooth.tick(with: snapshot.level)
        let peak = peakSmooth.tick(with: snapshot.peak)
        let low = curve(snapshot.low)
        let mid = curve(snapshot.mid)
        let high = curve(snapshot.high)
        let absClamp = max(0, min(1, abstraction))
        let biasClamp = max(0, min(1, energyBias))

        if snapshot.peak > kPeakImpulseThreshold && snapshot.peak > prevPeak {
            impulse = 1.0
        } else {
            impulse *= kImpulseDecay
        }
        impulse = min(1, max(0, impulse))
        prevPeak = snapshot.peak

        let mot = max(0, min(1, motion))
        let noi = max(0, min(1, noise))
        let gli = max(0, min(1, glitch))

        let speedMul = 0.25 + (4.0 - 0.25) * mot
        let ampMul = 0.05 + (1.25 - 0.05) * mot
        let seedPhase1 = Float(seed % 1000) / 1000 * Float.pi * 2
        let seedPhase2 = Float((seed >> 10) % 1000) / 1000 * Float.pi * 2
        let seedPhase3 = Float((seed >> 20) % 1000) / 1000 * Float.pi * 2
        let lfo1 = ampMul * sin(time * 0.6 * speedMul + seedPhase1)
        let lfo2 = ampMul * sin(time * 1.1 * speedMul + seedPhase2)
        let t3 = time * 0.4 * speedMul + seedPhase3
        let lfo3 = ampMul * (2 * abs(t3.truncatingRemainder(dividingBy: 1) - 0.5) - 0.5)

        let impactNorm = min(1, max(0, snapshot.impact))
        let trigger = (impulse > kGlitchImpulseThreshold || impactNorm > kGlitchImpulseThreshold) && gli > 0.01
        if trigger && detRandGlitch(seed: seed, time: time) < gli * 0.8 {
            glitchPhase = 1.0
        } else {
            glitchPhase *= kGlitchDecay
        }
        glitchPhase = min(1, max(0, glitchPhase))

        let shapeCount = mix(5, 60, absClamp)
        let noiseStrength = mix(0.05, 0.6, absClamp)
        let warpAmount = mix(0.02, 0.5, absClamp)
        let motionSpeed = mix(0.2, 1.5, absClamp)
        let trailAmount = mix(0.1, 0.8, absClamp)
        let reactivity = min(1, mix(low, high, biasClamp) * 1.2)

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
            trailPersistence: trailAmount,
            shapeStyleIndex: shapeStyleIndex,
            shapeCount: shapeCount,
            noiseStrength: noiseStrength,
            motionSpeed: motionSpeed,
            reactivity: reactivity,
            smoothedLow: snapshot.low,
            smoothedMid: snapshot.mid,
            smoothedHigh: snapshot.high,
            impact: min(1, max(0, snapshot.impact)),
            impulse: impulse,
            sceneType: max(0, min(2, sceneTypeIndex)),
            motion: mot,
            noise: noi,
            glitch: gli,
            lfo1: lfo1,
            lfo2: lfo2,
            lfo3: lfo3,
            speedMul: speedMul,
            glitchPhase: glitchPhase
        )
    }

    private func mix(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a + (b - a) * max(0, min(1, t))
    }

    private func curve(_ x: Float) -> Float {
        let c = max(0, min(1, x))
        return c * c * (3 - 2 * c)
    }

    /// Reset impulse/glitch transient state. Call from render thread (e.g. from provider when requested).
    func resetTransients() {
        impulse = 0
        glitchPhase = 0
        prevPeak = 0
    }
}
