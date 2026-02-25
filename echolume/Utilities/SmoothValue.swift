//
//  SmoothValue.swift
//  echolume
//
//  Simple attack/release smoothing for meter and param display.
//

import Foundation

/// One-pole smoother: attack fast, release slower.
/// Call `tick(with:)` each frame with the new target value.
final class SmoothValue: Sendable {
    private var current: Float
    private let attackCoeff: Float
    private let releaseCoeff: Float

    /// - Parameters:
    ///   - initial: Starting value (e.g. 0).
    ///   - attackCoeff: 0…1; higher = faster attack (e.g. 0.3).
    ///   - releaseCoeff: 0…1; higher = faster release (e.g. 0.02).
    init(initial: Float = 0, attackCoeff: Float = 0.3, releaseCoeff: Float = 0.02) {
        self.current = initial
        self.attackCoeff = attackCoeff
        self.releaseCoeff = releaseCoeff
    }

    /// Update with new target; returns smoothed value.
    func tick(with target: Float) -> Float {
        if target > current {
            current += (target - current) * attackCoeff
        } else {
            current += (target - current) * releaseCoeff
        }
        return current
    }

    var value: Float { current }

    func reset(to value: Float = 0) {
        current = value
    }
}
