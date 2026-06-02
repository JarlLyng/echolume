//
//  AudioAnalyzer.swift
//  echolume
//
//  RMS, peak, and FFT bands (low/mid/high). Envelope smoothing per band (fast attack, slower release).
//  Transient impact when low band increases rapidly. No allocations in process path.
//

import Accelerate
import Combine
import Foundation
import QuartzCore

/// Envelope: attack 0.05 (fast), release 0.25 (slower).
private let kEnvelopeAttack: Float = 0.05
private let kEnvelopeRelease: Float = 0.25
private let kImpactRiseThreshold: Float = 0.25
private let kImpactDecay: Float = 0.9

/// Computes RMS, peak, and 3-band FFT (low/mid/high). Exposes envelope-smoothed bands and impact.
final class AudioAnalyzer {
    let rmsPublisher = PassthroughSubject<Float, Never>()
    let peakPublisher = PassthroughSubject<Float, Never>()
    let lowPublisher = PassthroughSubject<Float, Never>()
    let midPublisher = PassthroughSubject<Float, Never>()
    let highPublisher = PassthroughSubject<Float, Never>()
    let impactPublisher = PassthroughSubject<Float, Never>()
    let beatPublisher = PassthroughSubject<BeatTracker.Output, Never>()
    /// Log-spaced, normalized, smoothed magnitude spectrum (kSpectrumBins values, 0…1),
    /// sent once per FFT frame for spectrum-style scenes.
    let spectrumPublisher = PassthroughSubject<[Float], Never>()

    private let beatTracker = BeatTracker()

    private let rmsSmoother = SmoothValue(initial: 0, attackCoeff: 0.35, releaseCoeff: 0.02)
    private let peakSmoother = SmoothValue(initial: 0, attackCoeff: 0.5, releaseCoeff: 0.08)
    private let lowEnvelope = SmoothValue(initial: 0, attackCoeff: kEnvelopeAttack, releaseCoeff: kEnvelopeRelease)
    private let midEnvelope = SmoothValue(initial: 0, attackCoeff: kEnvelopeAttack, releaseCoeff: kEnvelopeRelease)
    private let highEnvelope = SmoothValue(initial: 0, attackCoeff: kEnvelopeAttack, releaseCoeff: kEnvelopeRelease)

    private var sampleRate: Float = 48000
    private var fftProcessor: FFTProcessor?
    private let magnitudeBuffer: UnsafeMutablePointer<Float>
    private var runningLow: Float = 0.01
    private var runningMid: Float = 0.01
    private var runningHigh: Float = 0.01
    private var prevLowN: Float = 0
    private var impact: Float = 0

    // Spectrum (log-spaced bins) — preallocated, no per-call allocation except the
    // published copy. `spectrumBinStart` holds the FFT-bin boundary for each output bin.
    private var spectrumBins = [Float](repeating: 0, count: kSpectrumBins)
    private var spectrumScratch = [Float](repeating: 0, count: kSpectrumBins)
    private var spectrumBinStart = [Int](repeating: 0, count: kSpectrumBins + 1)
    private var spectrumRunningMax: Float = 0.001

    init() {
        magnitudeBuffer = UnsafeMutablePointer.allocate(capacity: kMagnitudeCount)
        fftProcessor = FFTProcessor()

        // Log-spaced FFT-bin boundaries (skip DC; up to the last magnitude bin),
        // so the spectrum is musically distributed rather than linear-in-frequency.
        let minBin = 1, maxBin = kMagnitudeCount - 1
        for k in 0 ... kSpectrumBins {
            let frac = Float(k) / Float(kSpectrumBins)
            let edge = Float(minBin) * powf(Float(maxBin) / Float(minBin), frac)
            spectrumBinStart[k] = min(maxBin, max(minBin, Int(edge.rounded())))
        }
        for k in 1 ... kSpectrumBins where spectrumBinStart[k] <= spectrumBinStart[k - 1] {
            spectrumBinStart[k] = min(maxBin, spectrumBinStart[k - 1] + 1)
        }
    }

    deinit {
        magnitudeBuffer.deallocate()
    }

    func setSampleRate(_ rate: Float) {
        sampleRate = rate > 0 ? rate : 48000
    }

    /// Register a manual tap. Call serialized with `process` (on the FFT queue).
    func tapTempo() {
        beatTracker.tap(now: CACurrentMediaTime())
    }

    /// Override BPM (nil re-enables auto-detection). Call on the FFT queue.
    func setManualBPM(_ bpm: Float?) {
        beatTracker.setManualBPM(bpm)
    }

    /// Process float PCM. For FFT we need at least 2048 samples; pass buffer of 2048 (e.g. from tap).
    func process(buffer: [Float]) {
        buffer.withUnsafeBufferPointer { process(buffer: $0) }
    }

    /// Process float PCM from pointer (allocation-free for audio callbacks).
    func process(buffer: UnsafeBufferPointer<Float>) {
        guard buffer.count > 0 else {
            let z: Float = 0
            rmsPublisher.send(rmsSmoother.tick(with: z))
            peakPublisher.send(peakSmoother.tick(with: z))
            lowPublisher.send(lowEnvelope.tick(with: z))
            midPublisher.send(midEnvelope.tick(with: z))
            highPublisher.send(highEnvelope.tick(with: z))
            impact *= kImpactDecay
            impactPublisher.send(min(1, max(0, impact)))
            return
        }

        var sumSq: Float = 0
        var peak: Float = 0
        for i in 0 ..< buffer.count {
            let s = buffer[i]
            let a = abs(s)
            sumSq += s * s
            if a > peak { peak = a }
        }
        let rms = sqrt(sumSq / Float(buffer.count))
        let rmsNorm = min(1, rms)
        let peakNorm = min(1, peak)
        rmsPublisher.send(rmsSmoother.tick(with: rmsNorm))
        peakPublisher.send(peakSmoother.tick(with: peakNorm))

        if buffer.count >= kFFTSize, let fft = fftProcessor, let base = buffer.baseAddress {
            fft.process(samples: base, magnitudeOut: magnitudeBuffer)
            let (lowRaw, midRaw, highRaw) = magnitudeSpectrumToBands(
                    magnitude: magnitudeBuffer,
                    binCount: kMagnitudeCount,
                    sampleRate: sampleRate
                )
            runningLow = max(runningLow * 0.997, lowRaw * 0.3)
            runningMid = max(runningMid * 0.997, midRaw * 0.3)
            runningHigh = max(runningHigh * 0.997, highRaw * 0.3)
            let lowN = min(1, lowRaw / (runningLow + 0.001))
            let midN = min(1, midRaw / (runningMid + 0.001))
            let highN = min(1, highRaw / (runningHigh + 0.001))

            let onsetStrength = max(0, lowN - prevLowN)
            if lowN - prevLowN > kImpactRiseThreshold {
                impact = 1.0
            } else {
                impact *= kImpactDecay
            }
            impact = min(1, max(0, impact))
            prevLowN = lowN

            // Beat tracking from the low-band onset envelope (runs on the FFT queue).
            let beat = beatTracker.ingest(onsetStrength: onsetStrength, now: CACurrentMediaTime())
            beatPublisher.send(beat)

            let smoothedLow = lowEnvelope.tick(with: lowN)
            let smoothedMid = midEnvelope.tick(with: midN)
            let smoothedHigh = highEnvelope.tick(with: highN)
            lowPublisher.send(smoothedLow)
            midPublisher.send(smoothedMid)
            highPublisher.send(smoothedHigh)
            impactPublisher.send(impact)

            computeSpectrum()
            spectrumPublisher.send(spectrumBins)
        }
    }

    /// Aggregate the linear magnitude spectrum into kSpectrumBins log-spaced bins,
    /// compress, normalize against a running max, and smooth per bin (fast attack,
    /// slower release). Fills `spectrumBins` in place.
    private func computeSpectrum() {
        var frameMax: Float = 0
        for k in 0 ..< kSpectrumBins {
            let lo = spectrumBinStart[k]
            let hi = max(lo + 1, spectrumBinStart[k + 1])
            var sum: Float = 0
            var n = 0
            var i = lo
            while i < hi && i < kMagnitudeCount {
                sum += magnitudeBuffer[i]
                n += 1
                i += 1
            }
            let avg = n > 0 ? sum / Float(n) : 0
            let comp = log1pf(avg * 8.0)   // log compression for a musical dynamic range
            spectrumScratch[k] = comp
            if comp > frameMax { frameMax = comp }
        }
        spectrumRunningMax = max(spectrumRunningMax * 0.999, frameMax)
        let norm = 1.0 / (spectrumRunningMax + 0.0001)
        for k in 0 ..< kSpectrumBins {
            let target = min(1, spectrumScratch[k] * norm)
            let prev = spectrumBins[k]
            let coeff: Float = target > prev ? 0.5 : 0.15   // fast attack, slow release
            spectrumBins[k] = prev + (target - prev) * coeff
        }
    }
}
