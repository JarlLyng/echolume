//
//  PluginSpectrumAnalyzer.swift
//  EcholumeAudioTap
//
//  vDSP FFT + log-spaced 64-bin reduction for the plugin's spectrum feed.
//  Mirrors the app's AudioAnalyzer shaping (log compression, running-max
//  normalization, fast-attack/slow-release smoothing) so per-bin scenes look
//  the same whether the app captures audio itself or the plugin drives it.
//  Runs entirely on the OSC sender's utility thread — never on the render
//  thread (#51).
//

import Accelerate
import Foundation

/// Must match kSpectrumBins in the app (the OSC message carries this many floats).
let kPluginSpectrumBins = 64

/// FFT window: 2048 samples -> 1024 half-spectrum -> 513 usable magnitudes.
let kPluginFFTSize = 2048
private let kHalfN = 1024
private let kMagnitudes = 513

final class PluginSpectrumAnalyzer {
    private var fftSetup: FFTSetup?
    private let realIn: UnsafeMutablePointer<Float>
    private let imagIn: UnsafeMutablePointer<Float>
    private let magnitude: UnsafeMutablePointer<Float>
    private let window: UnsafeMutablePointer<Float>
    private let windowed: UnsafeMutablePointer<Float>

    /// Log-spaced FFT-bin boundary for each output bin (skip DC).
    private var binStart = [Int](repeating: 0, count: kPluginSpectrumBins + 1)
    private var scratch = [Float](repeating: 0, count: kPluginSpectrumBins)
    private var runningMax: Float = 0.001

    /// Latest shaped bins (0...1), oldest state carried for smoothing.
    private(set) var bins = [Float](repeating: 0, count: kPluginSpectrumBins)

    init?() {
        realIn = .allocate(capacity: kHalfN)
        imagIn = .allocate(capacity: kHalfN)
        magnitude = .allocate(capacity: kMagnitudes)
        window = .allocate(capacity: kPluginFFTSize)
        windowed = .allocate(capacity: kPluginFFTSize)
        vDSP_hann_window(window, vDSP_Length(kPluginFFTSize), Int32(vDSP_HANN_NORM))
        guard let setup = vDSP_create_fftsetup(vDSP_Length(10), FFTRadix(kFFTRadix2)) else { return nil }
        fftSetup = setup

        // Same log-spaced boundaries as the app: musically distributed bins.
        let minBin = 1, maxBin = kMagnitudes - 1
        for k in 0 ... kPluginSpectrumBins {
            let frac = Float(k) / Float(kPluginSpectrumBins)
            let edge = Float(minBin) * powf(Float(maxBin) / Float(minBin), frac)
            binStart[k] = min(maxBin, max(minBin, Int(edge.rounded())))
        }
        for k in 1 ... kPluginSpectrumBins where binStart[k] <= binStart[k - 1] {
            binStart[k] = min(maxBin, binStart[k - 1] + 1)
        }
    }

    deinit {
        if let setup = fftSetup { vDSP_destroy_fftsetup(setup) }
        realIn.deallocate()
        imagIn.deallocate()
        magnitude.deallocate()
        window.deallocate()
        windowed.deallocate()
    }

    /// Run one FFT over `samples` (kPluginFFTSize floats) and refresh `bins`.
    func process(samples: UnsafePointer<Float>) {
        guard let setup = fftSetup else { return }
        vDSP_vmul(samples, 1, window, 1, windowed, 1, vDSP_Length(kPluginFFTSize))
        for i in 0 ..< kHalfN {
            realIn[i] = windowed[2 * i]
            imagIn[i] = windowed[2 * i + 1]
        }
        var split = DSPSplitComplex(realp: realIn, imagp: imagIn)
        vDSP_fft_zrip(setup, &split, 1, vDSP_Length(10), FFTDirection(FFT_FORWARD))
        vDSP_zvmags(&split, 1, magnitude, 1, vDSP_Length(kMagnitudes))
        vvsqrtf(magnitude, magnitude, [Int32(kMagnitudes)])

        // Same shaping as the app's computeSpectrum: aggregate per log bin,
        // log-compress, normalize by a slowly-decaying running max, smooth.
        var frameMax: Float = 0
        for k in 0 ..< kPluginSpectrumBins {
            let lo = binStart[k]
            let hi = max(lo + 1, binStart[k + 1])
            var sum: Float = 0
            var n = 0
            var i = lo
            while i < hi && i < kMagnitudes {
                sum += magnitude[i]
                n += 1
                i += 1
            }
            let avg = n > 0 ? sum / Float(n) : 0
            let comp = log1pf(avg * 8.0)
            scratch[k] = comp
            if comp > frameMax { frameMax = comp }
        }
        runningMax = max(runningMax * 0.999, frameMax)
        let norm = 1.0 / (runningMax + 0.0001)
        for k in 0 ..< kPluginSpectrumBins {
            let target = min(1, scratch[k] * norm)
            let prev = bins[k]
            let coeff: Float = target > prev ? 0.5 : 0.15   // fast attack, slow release
            bins[k] = prev + (target - prev) * coeff
        }
    }
}
