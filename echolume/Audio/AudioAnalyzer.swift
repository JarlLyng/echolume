//
//  AudioAnalyzer.swift
//  echolume
//
//  RMS, peak, and FFT bands (low/mid/high). Smoothed and normalized 0…1.
//

import Accelerate
import Combine
import Foundation

/// Computes RMS, peak, and 3-band FFT (low/mid/high). Exposes smoothed values for UI and mapping.
final class AudioAnalyzer {
    let rmsPublisher = PassthroughSubject<Float, Never>()
    let peakPublisher = PassthroughSubject<Float, Never>()
    let lowPublisher = PassthroughSubject<Float, Never>()
    let midPublisher = PassthroughSubject<Float, Never>()
    let highPublisher = PassthroughSubject<Float, Never>()

    private let rmsSmoother = SmoothValue(initial: 0, attackCoeff: 0.35, releaseCoeff: 0.02)
    private let peakSmoother = SmoothValue(initial: 0, attackCoeff: 0.5, releaseCoeff: 0.08)
    private let lowSmoother = SmoothValue(initial: 0, attackCoeff: 0.2, releaseCoeff: 0.03)
    private let midSmoother = SmoothValue(initial: 0, attackCoeff: 0.25, releaseCoeff: 0.03)
    private let highSmoother = SmoothValue(initial: 0, attackCoeff: 0.35, releaseCoeff: 0.02)

    private var sampleRate: Float = 48000
    private var fftProcessor: FFTProcessor?
    private let magnitudeBuffer: UnsafeMutablePointer<Float>
    private var runningLow: Float = 0.01
    private var runningMid: Float = 0.01
    private var runningHigh: Float = 0.01

    init() {
        magnitudeBuffer = UnsafeMutablePointer.allocate(capacity: kMagnitudeCount)
        fftProcessor = FFTProcessor()
    }

    deinit {
        magnitudeBuffer.deallocate()
    }

    func setSampleRate(_ rate: Float) {
        sampleRate = rate > 0 ? rate : 48000
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
            lowPublisher.send(lowSmoother.tick(with: z))
            midPublisher.send(midSmoother.tick(with: z))
            highPublisher.send(highSmoother.tick(with: z))
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
                lowPublisher.send(lowSmoother.tick(with: lowN))
                midPublisher.send(midSmoother.tick(with: midN))
                highPublisher.send(highSmoother.tick(with: highN))
        }
    }
}
