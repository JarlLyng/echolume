//
//  FFT.swift
//  echolume
//
//  vDSP real FFT (2048 samples -> 513 magnitude bins), band binning for low/mid/high.
//  Reuses buffers to avoid allocations per callback.
//

import Accelerate
import Foundation

let kFFTSize = 2048
let kFFTHalfN = 1024
let kMagnitudeCount = 513

/// Number of log-spaced spectrum bins exposed to the renderer (e.g. spectrum-ring scene).
let kSpectrumBins = 64

func magnitudeSpectrumToBands(
    magnitude: UnsafePointer<Float>,
    binCount: Int,
    sampleRate: Float
) -> (low: Float, mid: Float, high: Float) {
    guard sampleRate > 0, binCount >= 2 else { return (0, 0, 0) }
    let binFreq = sampleRate / Float(kFFTSize)
    let lowEnd = min(binCount - 1, max(0, Int(200 / binFreq)))
    let midEnd = min(binCount - 1, max(0, Int(2000 / binFreq)))
    let highEnd = min(binCount - 1, max(0, Int(12000 / binFreq)))
    let lowStart = max(1, Int(20 / binFreq))
    var low: Float = 0, mid: Float = 0, high: Float = 0
    for i in lowStart ... lowEnd { low += magnitude[i] }
    for i in (lowEnd + 1) ... midEnd { mid += magnitude[i] }
    for i in (midEnd + 1) ... highEnd { high += magnitude[i] }
    return (low, mid, high)
}

final class FFTProcessor {
    private var fftSetup: FFTSetup?
    private let realIn: UnsafeMutablePointer<Float>
    private let imagIn: UnsafeMutablePointer<Float>
    private let magnitudeSq: UnsafeMutablePointer<Float>
    private let window: UnsafeMutablePointer<Float>
    private let windowed: UnsafeMutablePointer<Float>
    private let frameCount = kFFTSize
    private let halfN = kFFTHalfN

    init?() {
        realIn = UnsafeMutablePointer.allocate(capacity: halfN)
        imagIn = UnsafeMutablePointer.allocate(capacity: halfN)
        magnitudeSq = UnsafeMutablePointer.allocate(capacity: kMagnitudeCount)
        window = UnsafeMutablePointer.allocate(capacity: frameCount)
        windowed = UnsafeMutablePointer.allocate(capacity: frameCount)
        vDSP_hann_window(window, vDSP_Length(frameCount), Int32(vDSP_HANN_NORM))
        guard let setup = vDSP_create_fftsetup(vDSP_Length(10), FFTRadix(kFFTRadix2)) else {
            return nil
        }
        fftSetup = setup
    }

    deinit {
        if let setup = fftSetup { vDSP_destroy_fftsetup(setup) }
        realIn.deallocate()
        imagIn.deallocate()
        magnitudeSq.deallocate()
        window.deallocate()
        windowed.deallocate()
    }

    /// Process 2048 samples; write 513 magnitudes to magnitudeOut. No allocations per call.
    func process(samples: UnsafePointer<Float>, magnitudeOut: UnsafeMutablePointer<Float>) {
        for i in 0 ..< frameCount { windowed[i] = samples[i] }
        vDSP_vmul(windowed, 1, window, 1, windowed, 1, vDSP_Length(frameCount))
        for i in 0 ..< halfN {
            realIn[i] = windowed[2 * i]
            imagIn[i] = windowed[2 * i + 1]
        }
        var split = DSPSplitComplex(realp: realIn, imagp: imagIn)
        vDSP_fft_zrip(fftSetup!, &split, 1, vDSP_Length(10), FFTDirection(FFT_FORWARD))
        vDSP_zvmags(&split, 1, magnitudeSq, 1, vDSP_Length(kMagnitudeCount))
        vvsqrtf(magnitudeOut, magnitudeSq, [Int32(kMagnitudeCount)])
    }

    func process(samples: [Float], magnitudeOut: UnsafeMutablePointer<Float>) -> Bool {
        guard samples.count >= frameCount else { return false }
        samples.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            process(samples: base, magnitudeOut: magnitudeOut)
        }
        return true
    }
}
