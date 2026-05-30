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
import Sentry
#if canImport(Darwin)
import Darwin
#endif

private let kTapBufferSize: UInt32 = 512
private let kRingCapacity = 4096
private let kFFTWindowSize = 2048
private let kFFTBacklogLimit = kFFTWindowSize * 2
private let kRestartDebounceMs: Int = 250

/// Wrapper around os_unfair_lock. Faster than NSLock and supports try_lock,
/// which lets the realtime audio callback skip a buffer instead of blocking.
final class UnfairLock {
    private let lockPointer: UnsafeMutablePointer<os_unfair_lock_s>
    init() {
        lockPointer = .allocate(capacity: 1)
        lockPointer.initialize(to: os_unfair_lock_s())
    }
    deinit {
        lockPointer.deinitialize(count: 1)
        lockPointer.deallocate()
    }
    @inline(__always) func lock() { os_unfair_lock_lock(lockPointer) }
    @inline(__always) func unlock() { os_unfair_lock_unlock(lockPointer) }
    /// Returns true if the lock was acquired.
    @inline(__always) func tryLock() -> Bool { os_unfair_lock_trylock(lockPointer) }
}

/// Atomic, race-free view of AudioManager state for cross-thread reads.
/// All fields are value-typed and copied under a single lock so the UI
/// layer always observes a coherent moment in time.
struct AudioManagerSnapshot: Equatable {
    var engineRunning: Bool = false
    var lastError: String? = nil
    var formatSampleRate: Double = 0
    var formatChannelCount: AVAudioChannelCount = 0
    var rms: Float = 0
    var peak: Float = 0
    var frameCount: UInt32 = 0
    var channelCount: Int = 0
    var lastTapDurationNs: Float = 0
}

final class AudioManager {
    /// Serial queue: all stop → create → set device → tap → start run here. No overlapping restarts.
    private let audioManagerQueue = DispatchQueue(label: "echolume.audio.manager", qos: .userInitiated)
    private var isRestarting = false
    private var debounceWorkItem: DispatchWorkItem?
    private let pendingLock = NSLock()
    /// Latest requested device for debounce; main thread sets, queue reads.
    private var _pendingRestartDeviceID: AudioDeviceID?

    /// New engine per start; nil after tear down. Only mutated on audioManagerQueue.
    private var engine: AVAudioEngine?
    private let analyzer = AudioAnalyzer()

#if DEBUG
    private var _timebaseNumer: UInt32 = 1
    private var _timebaseDenom: UInt32 = 1
#endif

    private var ringBuffer: [Float]
    private var ringWriteIndex: Int = 0
    private var ringReadIndex: Int = 0
    /// Producer (audio tap) uses tryLock to never block on realtime path.
    /// Consumer (FFT queue) uses regular lock — it's fine for it to wait.
    private let ringLock = UnfairLock()
    private var processBuffer: [Float]

    /// Single source of truth for cross-thread state. Always accessed under stateLock.
    private let stateLock = UnfairLock()
    private var _snapshot = AudioManagerSnapshot()

    /// Selected channel pair for downmix; mutated from main, read on audioManagerQueue.
    private let channelPairLock = UnfairLock()
    private var _selectedChannelPairIndex: Int = 0
    var selectedChannelPairIndex: Int {
        get { channelPairLock.lock(); defer { channelPairLock.unlock() }; return _selectedChannelPairIndex }
        set { channelPairLock.lock(); _selectedChannelPairIndex = newValue; channelPairLock.unlock() }
    }


    private let fftQueue = DispatchQueue(label: "echolume.fft", qos: .userInitiated)
    private var fftSource: DispatchSourceUserDataOr?

    /// Atomic snapshot of audio engine state. Safe to read from any thread.
    var snapshot: AudioManagerSnapshot {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _snapshot
    }

    private func mutateSnapshot(_ change: (inout AudioManagerSnapshot) -> Void) {
        stateLock.lock()
        change(&_snapshot)
        stateLock.unlock()
    }

    var lowPublisher: AnyPublisher<Float, Never> { analyzer.lowPublisher.eraseToAnyPublisher() }
    var midPublisher: AnyPublisher<Float, Never> { analyzer.midPublisher.eraseToAnyPublisher() }
    var highPublisher: AnyPublisher<Float, Never> { analyzer.highPublisher.eraseToAnyPublisher() }
    var impactPublisher: AnyPublisher<Float, Never> { analyzer.impactPublisher.eraseToAnyPublisher() }
    var beatPublisher: AnyPublisher<BeatTracker.Output, Never> { analyzer.beatPublisher.eraseToAnyPublisher() }

    /// Register a tap-tempo tap. Serialized onto the FFT queue so all beat
    /// tracker access happens on one thread.
    func tapTempo() {
        fftQueue.async { [weak self] in self?.analyzer.tapTempo() }
    }

    /// Override BPM (nil re-enables auto-detection).
    func setManualBPM(_ bpm: Float?) {
        fftQueue.async { [weak self] in self?.analyzer.setManualBPM(bpm) }
    }

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
        let source = DispatchSource.makeUserDataOrSource(queue: fftQueue)
        source.setEventHandler { [weak self] in self?.runFFT() }
        source.resume()
        fftSource = source
    }

    deinit {
        fftSource?.cancel()
        stopAndTearDownEngine()
    }

    /// Full tear down: remove tap, stop, discard engine. No logging in hot path.
    func stopAndTearDownEngine() {
        guard let eng = engine else { return }
        if eng.isRunning {
            eng.inputNode.removeTap(onBus: 0)
            eng.stop()
        }
        engine = nil
        mutateSnapshot { $0.engineRunning = false }
    }

    /// Called on audioManagerQueue only. One consolidated log line per failure.
    private func startEngine(withDeviceID deviceID: AudioDeviceID?) {
        mutateSnapshot { $0.lastError = nil }
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
                mutateSnapshot { $0.lastError = "Could not use selected input device; using current/default input." }
                #if DEBUG
                if !didLogThisRestart {
                    Log.warn("AudioManager: AudioUnitSetProperty(CurrentDevice) failed: \(err) (once per restart)")
                    didLogThisRestart = true
                }
                #endif
            }
        } else if let id = deviceID, id != 0, input.audioUnit == nil {
            mutateSnapshot { $0.lastError = "Could not use selected input device; using current/default input." }
            #if DEBUG
            if !didLogThisRestart {
                Log.warn("AudioManager: inputNode.audioUnit is nil (once per restart)")
                didLogThisRestart = true
            }
            #endif
        }

        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            mutateSnapshot {
                $0.lastError = $0.lastError ?? "Invalid input format: \(format.sampleRate) Hz, \(format.channelCount) ch"
                $0.engineRunning = false
            }
            engine = nil
            return
        }

        input.removeTap(onBus: 0)
        let chCount = Int(format.channelCount)
        mutateSnapshot { $0.channelCount = chCount }
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

            // Realtime contract: never block. If FFT consumer is mid-read,
            // we drop this audio buffer rather than wait. ringLock contention
            // is rare (consumer holds it for ~2µs to copy 2048 samples while
            // tap fires every ~12ms), so frame drops are negligible. The FFT
            // simply analyzes a slightly older window when this happens.
            guard self.ringLock.tryLock() else { return }

            var sumSq: Float = 0
            var peak: Float = 0
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

            let computedRms = sqrt(sumSq / Float(n))
            self.mutateSnapshot {
                $0.rms = computedRms
                $0.peak = peak
                $0.frameCount = UInt32(n)
            }

            if available >= kFFTWindowSize {
                self.scheduleFFT()
            }
#if DEBUG
            let t1 = mach_absolute_time()
            let durationNs = Float((t1 - t0) * UInt64(self._timebaseNumer) / UInt64(self._timebaseDenom))
            self.mutateSnapshot { $0.lastTapDurationNs = durationNs }
#endif
        }

        eng.prepare()
        do {
            try eng.start()
            mutateSnapshot {
                $0.formatSampleRate = format.sampleRate
                $0.formatChannelCount = format.channelCount
                $0.engineRunning = true
            }
            #if DEBUG
            if !didLogThisRestart { Log.info("AudioManager: started \(format.sampleRate) Hz \(format.channelCount) ch (once per restart)") }
            #endif
        } catch {
            mutateSnapshot {
                $0.lastError = "Could not use selected input device; using current/default input."
                $0.formatSampleRate = 0
                $0.formatChannelCount = 0
                $0.engineRunning = false
            }
            SentrySDK.capture(error: error) { scope in
                scope.setTag(value: "audio_engine_start", key: "failure_point")
            }
            #if DEBUG
            if !didLogThisRestart { Log.warn("AudioManager: engine.start failed: \(error.localizedDescription) (once per restart)") }
            #endif
        }
    }

    /// Signal FFT source — non-allocating, coalescing, real-time safe.
    private func scheduleFFT() {
        fftSource?.or(data: 1)
    }

    private func runFFT() {
        ringLock.lock()
        let w = ringWriteIndex
        var r = ringReadIndex
        let available = w - r
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

    /// Read selected channel pair (used by tests / for parity with the public setter).
    func currentChannelPairIndex() -> Int {
        selectedChannelPairIndex
    }

    static var microphonePermissionGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }
}
