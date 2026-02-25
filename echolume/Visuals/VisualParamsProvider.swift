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
    private var snapshot = AnalyzerSnapshot(level: 0, peak: 0, low: 0, mid: 0, high: 0)
    private var abstraction: Float = 0.5
    private var seed: UInt32 = 0
    private var themeIndex: Int = 0
    private let mapping = ParamMapping()

    /// Call from main thread when analyzer or user settings change.
    func update(snapshot: AnalyzerSnapshot, abstraction: Float, seed: UInt32, themeIndex: Int) {
        lock.lock()
        self.snapshot = snapshot
        self.abstraction = abstraction
        self.seed = seed
        self.themeIndex = max(0, min(themeIndex, ThemeLibrary.themes.count - 1))
        lock.unlock()
    }

    /// Call from render thread. Returns VisualParams for this frame.
    func params(time: Float, resolution: SIMD2<Float>) -> VisualParams {
        lock.lock()
        let snap = snapshot
        let abs = abstraction
        let s = seed
        let tIdx = themeIndex
        lock.unlock()
        let theme = ThemeLibrary.theme(byIndex: tIdx)
        return mapping.map(snapshot: snap, abstraction: abs, theme: theme, seed: s, time: time, resolution: resolution)
    }
}
