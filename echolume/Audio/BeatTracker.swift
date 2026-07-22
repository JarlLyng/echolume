//
//  BeatTracker.swift
//  echolume
//
//  Tempo + beat-phase estimation from a low-band onset-strength envelope.
//  Pure Swift (no CoreAudio) so the BPM/phase logic is unit-testable. Fed once
//  per analysis frame from AudioAnalyzer on the FFT queue.
//
//  BPM: direct autocorrelation of the recent onset envelope, restricted to the
//  80–180 BPM lag range, with parabolic interpolation of the peak for
//  sub-frame (hence sub-BPM) resolution. Phase: a sawtooth advanced by the
//  detected tempo and softly corrected toward detected onsets (a simple PLL).
//

import Foundation

final class BeatTracker {
    struct Output: Equatable {
        var bpm: Float
        var beatPhase: Float   // 0...1 sawtooth, 0 == beat
        var confidence: Float  // 0...1, autocorrelation peak prominence
    }

    // Tempo search range.
    private let minBPM: Float = 80
    private let maxBPM: Float = 180

    // Onset history (most-recent-last), one sample per analysis frame.
    private let capacity = 512
    private var history = [Float]()
    private var scratch: [Float]
    /// Preallocated autocorrelation buffer (reused each estimate; no per-call heap alloc).
    private var acorr: [Float]

    // Timing.
    private var lastNow: Double = -1
    private var emaDt: Double = 0.0427   // ~FFT cadence; refined from real deltas
    private var timeSinceEstimate: Double = 0

    // Tempo state.
    private var detectedBPM: Float = 0
    private var manualBPM: Float?
    private var confidence: Float = 0

    // Phase state.
    private var phase: Float = 0
    private let phaseCorrectionGain: Float = 0.08
    private var recentOnsetAvg: Float = 0.01

    // Tap tempo.
    private var tapTimes = [Double]()

    init() {
        history.reserveCapacity(capacity)
        scratch = [Float](repeating: 0, count: capacity)
        acorr = [Float](repeating: 0, count: capacity + 2)
    }

    /// The tempo currently in effect (manual override wins).
    private var activeBPM: Float { manualBPM ?? detectedBPM }

    /// Feed one onset-strength sample. Returns the current tempo + phase.
    @discardableResult
    func ingest(onsetStrength: Float, now: Double) -> Output {
        let dt: Double
        if lastNow < 0 {
            dt = emaDt
        } else {
            dt = min(0.2, max(0.005, now - lastNow))
            emaDt = emaDt * 0.95 + dt * 0.05
        }
        lastNow = now

        // History ring (drop oldest when full).
        history.append(onsetStrength)
        if history.count > capacity { history.removeFirst(history.count - capacity) }

        // Track a slow average onset level for thresholding.
        recentOnsetAvg = recentOnsetAvg * 0.99 + onsetStrength * 0.01

        // Re-estimate tempo a few times per second (cheap, but not every frame).
        timeSinceEstimate += dt
        if manualBPM == nil, timeSinceEstimate >= 0.25 {
            timeSinceEstimate = 0
            estimateTempo()
        }

        // Advance phase at the active tempo.
        let bpm = activeBPM
        if bpm > 0 {
            phase = wrap01(phase + Float(dt) * bpm / 60.0)
            // PLL: a strong onset marks a beat — pull phase toward 0.
            if onsetStrength > max(0.15, recentOnsetAvg * 2.5) {
                let err: Float = phase < 0.5 ? phase : phase - 1.0
                phase = wrap01(phase - phaseCorrectionGain * err)
            }
        }

        return Output(bpm: bpm, beatPhase: phase, confidence: confidence)
    }

    /// Register a manual tap. Two or more taps at a sane interval set the tempo
    /// and reset the phase (the tap is treated as a downbeat).
    func tap(now: Double) {
        // Drop stale taps (> 2s gap restarts the sequence).
        if let last = tapTimes.last, now - last > 2.0 { tapTimes.removeAll() }
        tapTimes.append(now)
        if tapTimes.count > 4 { tapTimes.removeFirst(tapTimes.count - 4) }

        if tapTimes.count >= 2 {
            var total = 0.0
            for i in 1 ..< tapTimes.count { total += tapTimes[i] - tapTimes[i - 1] }
            let avg = total / Double(tapTimes.count - 1)
            if avg > 0 {
                let bpm = Float(60.0 / avg)
                manualBPM = min(max(bpm, 60), 200)
                confidence = 1
            }
        }
        phase = 0   // tap == downbeat
    }

    /// Set a manual BPM (nil re-enables auto-detection).
    func setManualBPM(_ bpm: Float?) {
        if let bpm { manualBPM = min(max(bpm, 60), 200) } else { manualBPM = nil; tapTimes.removeAll() }
    }

    // MARK: - Tempo estimation

    private func estimateTempo() {
        let n = history.count
        guard n >= 16 else { return }

        // Copy recent history into scratch and remove DC (mean) for cleaner peaks.
        var mean: Float = 0
        for i in 0 ..< n { mean += history[i] }
        mean /= Float(n)
        for i in 0 ..< n { scratch[i] = history[i] - mean }

        let minLag = max(1, Int((60.0 / Double(maxBPM)) / emaDt))
        let maxLag = min(n - 1, Int((60.0 / Double(minBPM)) / emaDt))
        guard maxLag > minLag + 1 else { return }

        // Direct autocorrelation over the candidate lag range.
        var bestLag = minLag
        var bestVal: Float = -.greatestFiniteMagnitude
        var sumVal: Float = 0
        var count = 0
        // Reuse the preallocated `acorr` buffer; indices [minLag...maxLag] are written before read.
        for lag in minLag ... maxLag {
            var acc: Float = 0
            for i in 0 ..< (n - lag) { acc += scratch[i] * scratch[i + lag] }
            acc /= Float(n - lag)
            acorr[lag] = acc
            sumVal += acc
            count += 1
            if acc > bestVal { bestVal = acc; bestLag = lag }
        }
        guard count > 0, bestVal > 0 else { confidence = 0; return }

        // Parabolic interpolation around the peak for sub-frame lag precision.
        var refinedLag = Float(bestLag)
        if bestLag > minLag, bestLag < maxLag {
            let a = acorr[bestLag - 1], b = acorr[bestLag], c = acorr[bestLag + 1]
            let denom = a - 2 * b + c
            if abs(denom) > 1e-9 {
                let delta = 0.5 * (a - c) / denom
                if delta > -1, delta < 1 { refinedLag = Float(bestLag) + delta }
            }
        }

        let newBPM = Float(60.0 / (Double(refinedLag) * emaDt))
        guard newBPM.isFinite, newBPM >= minBPM - 5, newBPM <= maxBPM + 5 else { return }

        // Confidence: peak prominence over the mean autocorrelation.
        let meanVal = sumVal / Float(count)
        let prominence = meanVal > 0 ? (bestVal - meanVal) / (bestVal + 1e-6) : 0
        confidence = min(1, max(0, prominence))

        // Smooth BPM once we have an estimate; snap if far off (initial lock).
        if detectedBPM <= 0 || abs(newBPM - detectedBPM) > 12 {
            detectedBPM = newBPM
        } else {
            detectedBPM = detectedBPM * 0.7 + newBPM * 0.3
        }
    }

    private func wrap01(_ x: Float) -> Float {
        var v = x.truncatingRemainder(dividingBy: 1)
        if v < 0 { v += 1 }
        return v
    }
}
