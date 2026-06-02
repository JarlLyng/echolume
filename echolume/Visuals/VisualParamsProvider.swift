//
//  VisualParamsProvider.swift
//  echolume
//
//  Thread-safe provider of VisualParams for the renderer. Main thread updates snapshot;
//  render thread reads and runs ParamMapping.
//

import Foundation
import simd

final class VisualParamsProvider: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot = AnalyzerSnapshot(level: 0, peak: 0, low: 0, mid: 0, high: 0, impact: 0)
    private var abstraction: Float = 0.5
    private var seed: UInt32 = 0
    private var themeIndex: Int = 0
    private var shapeStyleIndex: Int = 0
    private var sceneTypeIndex: Int = 0
    private var energyBias: Float = 0.5
    private var motion: Float = 0.5
    private var noise: Float = 0.5
    private var glitch: Float = 0.2
    private var hasSignal: Bool = true
    private var resetTransientsRequested: Bool = false
    private var trailResetRequested: Bool = false
    private var spectrum = [Float](repeating: 0, count: kSpectrumBins)
    private let mapping = ParamMapping()

    /// Call from main thread when analyzer or user settings change.
    func update(snapshot: AnalyzerSnapshot, abstraction: Float, seed: UInt32, themeIndex: Int, shapeStyleIndex: Int, sceneTypeIndex: Int, energyBias: Float, motion: Float, noise: Float, glitch: Float, hasSignal: Bool = true) {
        lock.lock()
        self.snapshot = snapshot
        self.abstraction = abstraction
        self.seed = seed
        self.themeIndex = max(0, min(themeIndex, ThemeLibrary.themes.count - 1))
        self.shapeStyleIndex = max(0, min(shapeStyleIndex, 4))
        self.sceneTypeIndex = max(0, min(sceneTypeIndex, SceneType.allCases.count - 1))
        self.energyBias = max(0, min(1, energyBias))
        self.motion = max(0, min(1, motion))
        self.noise = max(0, min(1, noise))
        self.glitch = max(0, min(1, glitch))
        self.hasSignal = hasSignal
        lock.unlock()
    }

    /// Update the spectrum bins (once per FFT frame). Call from main thread.
    func updateSpectrum(_ bins: [Float]) {
        lock.lock()
        let n = min(bins.count, spectrum.count)
        for i in 0 ..< n { spectrum[i] = bins[i] }
        lock.unlock()
    }

    /// Copy the current spectrum into `dest` (length kSpectrumBins). Call from the render thread.
    func copySpectrum(into dest: UnsafeMutablePointer<Float>) {
        lock.lock()
        for i in 0 ..< spectrum.count { dest[i] = spectrum[i] }
        lock.unlock()
    }

    /// Request transient reset on next params() call (panic reset). Call from main thread.
    func requestTransientReset() {
        lock.lock()
        resetTransientsRequested = true
        trailResetRequested = true
        lock.unlock()
    }

    /// Returns true once after a transient reset was requested, so the renderer
    /// can clear its feedback/trail textures. Call from the render thread.
    func consumeTrailReset() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let r = trailResetRequested
        trailResetRequested = false
        return r
    }

    /// Call from render thread. Returns VisualParams for this frame.
    func params(time: Float, resolution: SIMD2<Float>) -> VisualParams {
        lock.lock()
        let snap = snapshot
        let abs = abstraction
        let s = seed
        let tIdx = themeIndex
        let styleIdx = shapeStyleIndex
        let sceneIdx = sceneTypeIndex
        let bias = energyBias
        let mot = motion
        let noi = noise
        let gli = glitch
        let sig = hasSignal
        let resetReq = resetTransientsRequested
        resetTransientsRequested = false
        lock.unlock()
        if resetReq { mapping.resetTransients() }
        let theme = ThemeLibrary.theme(byIndex: tIdx)
        var p = mapping.map(snapshot: snap, abstraction: abs, energyBias: bias, theme: theme, seed: s, shapeStyleIndex: styleIdx, sceneTypeIndex: sceneIdx, time: time, resolution: resolution, motion: mot, noise: noi, glitch: gli)
        if !sig {
            p.impact = 0
            p.impulse = 0
        }
        return p
    }
}
