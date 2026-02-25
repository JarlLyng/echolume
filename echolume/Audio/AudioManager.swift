//
//  AudioManager.swift
//  echolume
//
//  Real in-app device switching via public API: inputNode.audioUnit + AudioUnitSetProperty.
//  Never changes system default. Tap stays realtime-safe.
//

import AVFoundation
import AudioToolbox
import Combine
import CoreAudio
import Foundation
#if canImport(Darwin)
import Darwin
#endif

private let kTapBufferSize: UInt32 = 512
private let kRingCapacity = 4096
private let kFFTWindowSize = 2048
private let kFFTBacklogLimit = kFFTWindowSize * 2
private let kRestartDebounceMs: Int = 250

final class AudioManager {
    /// Serial queue: all stop → create → set device → tap → start run here. No overlapping restarts.
    private let audioManagerQueue = DispatchQueue(label: "echolume.audio.manager", qos: .userInitiated)
    private var isRestarting = false
    private var debounceWorkItem: DispatchWorkItem?
    private let pendingLock = NSLock()
    /// Latest requested device for debounce; main thread sets, queue reads.
    private var _pendingRestartDeviceID: AudioDeviceID?

    /// New engine per start; nil after tear down.
    private var engine: AVAudioEngine?
    private let analyzer = AudioAnalyzer()

    private var _rms: Float = 0
    private var _peak: Float = 0
    private var _frameCount: UInt32 = 0
    private var _channelCount: Int = 0

#if DEBUG
    private var _lastTapDurationNs: Float = 0
    private var _timebaseNumer: UInt32 = 1
    private var _timebaseDenom: UInt32 = 1
#endif
    var lastTapDurationNs: Float {
#if DEBUG
        _lastTapDurationNs
#else
        0
#endif
    }

    private var ringBuffer: [Float]
    private var ringWriteIndex: Int = 0
    private var ringReadIndex: Int = 0
    private let ringLock = NSLock()
    private let statsLock = NSLock()
    private var processBuffer: [Float]

    private(set) var lastError: String?
    private(set) var formatSampleRate: Double = 0
    private(set) var formatChannelCount: AVAudioChannelCount = 0

    /// Channel pair for downmix: 0 = ch 1–2, 1 = ch 3–4, …
    var selectedChannelPairIndex: Int = 0

    private let fftQueue = DispatchQueue(label: "echolume.fft", qos: .userInitiated)
    private var fftWorkItem: DispatchWorkItem?

    var engineRunning: Bool { engine?.isRunning ?? false }
    /// For UI: engine is running.
    var isRunning: Bool { engine?.isRunning ?? false }
    /// For UI: last start failure message.
    var lastErrorMessage: String? { lastError }
    var debugLastRMS: Float { statsLock.lock(); defer { statsLock.unlock() }; return _rms }
    var debugLastPeak: Float { statsLock.lock(); defer { statsLock.unlock() }; return _peak }
    var debugLastFrames: UInt32 { statsLock.lock(); defer { statsLock.unlock() }; return _frameCount }
    var debugChannelCount: Int { statsLock.lock(); defer { statsLock.unlock() }; return _channelCount }

    var lowPublisher: AnyPublisher<Float, Never> { analyzer.lowPublisher.eraseToAnyPublisher() }
    var midPublisher: AnyPublisher<Float, Never> { analyzer.midPublisher.eraseToAnyPublisher() }
    var highPublisher: AnyPublisher<Float, Never> { analyzer.highPublisher.eraseToAnyPublisher() }
    var impactPublisher: AnyPublisher<Float, Never> { analyzer.impactPublisher.eraseToAnyPublisher() }

    init() {
        ringBuffer = [Float](repeating: 0, count: kRingCapacity)
        processBuffer = [Float](repeating: 0, count: kFFTWindowSize)
#if DEBUG
        var info = mach_timebase_info_data_t()
        if mach_timebase_info(&info) == 0 {
            _timebaseNumer = info.numer
            _timebaseDenom = info.denom
        }
#endif
    }

    deinit {
        stopAndTearDownEngine()
    }

    /// Full tear down: remove tap, stop, discard engine. No logging in hot path.
    func stopAndTearDownEngine() {
        fftWorkItem?.cancel()
        fftWorkItem = nil
        guard let eng = engine else { return }
        if eng.isRunning {
            eng.inputNode.removeTap(onBus: 0)
            eng.stop()
        }
        engine = nil
    }

    /// Called on audioManagerQueue only. One consolidated log line per failure.
    private func startEngine(withDeviceID deviceID: AudioDeviceID?) {
        lastError = nil
        stopAndTearDownEngine()

        let eng = AVAudioEngine()
        self.engine = eng
        let input = eng.inputNode

        var didLogThisRestart = false
        if let id = deviceID, id != 0, let unit = input.audioUnit {
            var idCopy = id
            let size = UInt32(MemoryLayout<AudioDeviceID>.size)
            let err = AudioUnitSetProperty(
                unit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &idCopy,
                size
            )
            if err != noErr {
                lastError = "Could not use selected input device; using current/default input."
                #if DEBUG
                if !didLogThisRestart {
                    Log.warn("AudioManager: AudioUnitSetProperty(CurrentDevice) failed: \(err) (once per restart)")
                    didLogThisRestart = true
                }
                #endif
            }
        } else if let id = deviceID, id != 0, input.audioUnit == nil {
            lastError = "Could not use selected input device; using current/default input."
            #if DEBUG
            if !didLogThisRestart {
                Log.warn("AudioManager: inputNode.audioUnit is nil (once per restart)")
                didLogThisRestart = true
            }
            #endif
        }

        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            lastError = lastError ?? "Invalid input format: \(format.sampleRate) Hz, \(format.channelCount) ch"
            engine = nil
            return
        }

        input.removeTap(onBus: 0)
        let chCount = Int(format.channelCount)
        statsLock.lock()
        _channelCount = chCount
        statsLock.unlock()
        ringLock.lock()
        ringWriteIndex = 0
        ringReadIndex = 0
        ringLock.unlock()
        analyzer.setSampleRate(Float(format.sampleRate))

        let pairIdx = min(selectedChannelPairIndex, max(0, chCount / 2 - 1))
        let ch0 = min(pairIdx * 2, chCount - 1)
        let ch1 = chCount > 1 ? min(pairIdx * 2 + 1, chCount - 1) : ch0
        let cap = kRingCapacity

        input.installTap(onBus: 0, bufferSize: kTapBufferSize, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
#if DEBUG
            let t0 = mach_absolute_time()
#endif
            let n = Int(buffer.frameLength)
            guard let channelData = buffer.floatChannelData, n > 0 else { return }

            var sumSq: Float = 0
            var peak: Float = 0
            self.ringLock.lock()
            var w = self.ringWriteIndex
            if chCount == 1 {
                let ptr = channelData[0]
                for i in 0 ..< n {
                    let s = ptr[i]
                    sumSq += s * s
                    if abs(s) > peak { peak = abs(s) }
                    self.ringBuffer[w % cap] = s
                    w += 1
                }
            } else {
                let ptr0 = channelData[ch0]
                let ptr1 = channelData[ch1]
                for i in 0 ..< n {
                    let s = (ptr0[i] + ptr1[i]) * 0.5
                    sumSq += s * s
                    if abs(s) > peak { peak = abs(s) }
                    self.ringBuffer[w % cap] = s
                    w += 1
                }
            }
            self.ringWriteIndex = w
            if w - self.ringReadIndex > cap {
                self.ringReadIndex = w - cap
            }
            let available = self.ringWriteIndex - self.ringReadIndex
            self.ringLock.unlock()

            self.statsLock.lock()
            self._rms = sqrt(sumSq / Float(n))
            self._peak = peak
            self._frameCount = UInt32(n)
            self.statsLock.unlock()

            if available >= kFFTWindowSize {
                self.scheduleFFT()
            }
#if DEBUG
            let t1 = mach_absolute_time()
            self._lastTapDurationNs = Float((t1 - t0) * UInt64(self._timebaseNumer) / UInt64(self._timebaseDenom))
#endif
        }

        eng.prepare()
        do {
            try eng.start()
            formatSampleRate = format.sampleRate
            formatChannelCount = format.channelCount
            #if DEBUG
            if !didLogThisRestart { Log.info("AudioManager: started \(format.sampleRate) Hz \(format.channelCount) ch (once per restart)") }
            #endif
        } catch {
            lastError = "Could not use selected input device; using current/default input."
            formatSampleRate = 0
            formatChannelCount = 0
            #if DEBUG
            if !didLogThisRestart { Log.warn("AudioManager: engine.start failed: \(error.localizedDescription) (once per restart)") }
            #endif
        }
    }

    private func scheduleFFT() {
        fftWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.runFFT() }
        fftWorkItem = work
        fftQueue.async(execute: work)
    }

    private func runFFT() {
        ringLock.lock()
        let w = ringWriteIndex
        var r = ringReadIndex
        var available = w - r
        guard available >= kFFTWindowSize else {
            ringLock.unlock()
            return
        }
        if available > kFFTBacklogLimit {
            r = w - kFFTWindowSize
        }
        let cap = kRingCapacity
        for i in 0 ..< kFFTWindowSize {
            processBuffer[i] = ringBuffer[(r + i) % cap]
        }
        ringReadIndex = r + kFFTWindowSize
        ringLock.unlock()
        analyzer.process(buffer: processBuffer)
    }

    /// Single entry point for restart. Serial on audioManagerQueue; coalesced (request during restart runs once after).
    func restart(withDeviceID deviceID: AudioDeviceID?) {
        guard AudioManager.microphonePermissionGranted else { return }
        pendingLock.lock()
        _pendingRestartDeviceID = deviceID
        pendingLock.unlock()
        debounceWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.performRestartDebounced()
        }
        debounceWorkItem = item
        audioManagerQueue.asyncAfter(deadline: .now() + .milliseconds(kRestartDebounceMs), execute: item)
    }

    /// Runs on audioManagerQueue only. Guard prevents overlapping; coalesces by re-running once if a new request arrived during startEngine.
    private func performRestartDebounced() {
        guard !isRestarting else { return }
        pendingLock.lock()
        let deviceID = _pendingRestartDeviceID
        _pendingRestartDeviceID = nil
        pendingLock.unlock()
        debounceWorkItem = nil
        isRestarting = true
        startEngine(withDeviceID: deviceID)
        isRestarting = false
        pendingLock.lock()
        let hasMore = _pendingRestartDeviceID != nil
        pendingLock.unlock()
        if hasMore { performRestartDebounced() }
    }

    func setChannelPairIndex(_ index: Int) {
        selectedChannelPairIndex = max(0, index)
    }

    static var microphonePermissionGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }
}
