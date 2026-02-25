//
//  AudioManager.swift
//  echolume
//
//  Uses AVAudioEngine for input. Enumerates devices via CoreAudio.
//  Device switching: set system default input, then restart engine.
//

import AVFoundation
import Combine
import CoreAudio
import Foundation

private let kTapBufferSize: UInt32 = 512

final class AudioManager {
    private let analyzer = AudioAnalyzer()
    private var cancellables = Set<AnyCancellable>()

    private let engine = AVAudioEngine()
    private var tapInstallFormat: AVAudioFormat?
    private var selectedDeviceID: AudioDeviceID?
    private var sampleRate: Float = 48000

    /// Pre-allocated mono buffer for tap (no allocation in tap).
    private var monoBuffer: [Float]
    private let monoBufferCapacity = 2048

    var rmsPublisher: AnyPublisher<Float, Never> { analyzer.rmsPublisher.eraseToAnyPublisher() }
    var peakPublisher: AnyPublisher<Float, Never> { analyzer.peakPublisher.eraseToAnyPublisher() }
    var lowPublisher: AnyPublisher<Float, Never> { analyzer.lowPublisher.eraseToAnyPublisher() }
    var midPublisher: AnyPublisher<Float, Never> { analyzer.midPublisher.eraseToAnyPublisher() }
    var highPublisher: AnyPublisher<Float, Never> { analyzer.highPublisher.eraseToAnyPublisher() }

    var selectedChannelPairIndex: Int = 0

    /// No longer used (AUHAL removed); kept for DEBUG UI compatibility.
    private(set) var isUsingFallbackDevice: Bool = false
    var onFallbackToDefaultDevice: (() -> Void)?

    // Lock-free: written in tap, read by main-thread Timer.
    private var _debugLastRMS: Float = 0
    private var _debugLastPeak: Float = 0
    private var _debugLastFrames: UInt32 = 0
    private var _debugMaxAbs: Float = 0
    var isAUHALActive: Bool { false }
    var debugLastRMS: Float { _debugLastRMS }
    var debugLastPeak: Float { _debugLastPeak }
    var debugLastRenderStatus: OSStatus { noErr }
    var debugLastFrames: UInt32 { _debugLastFrames }
    var debugFirstSample: Float { 0 }
    var debugChannelCount: Int { 0 }
    var debugMaxAbs: Float { _debugMaxAbs }
    var debugFormatFlags: UInt32 = 0
    var debugBytesPerFrame: UInt32 = 0
    var debugInterleaved: Bool { true }

    init() {
        monoBuffer = [Float](repeating: 0, count: monoBufferCapacity)
    }

    deinit {
        stop()
    }

    // MARK: - Device enumeration (CoreAudio)

    static func enumerateInputDevices() -> [AudioDevice] {
        var devices = [AudioDevice]()
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let systemObjectID = AudioObjectID(kAudioObjectSystemObject)
        var err = AudioObjectGetPropertyDataSize(systemObjectID, &propertyAddress, 0, nil, &size)
        guard err == noErr, size > 0 else {
            Log.debug("AudioObjectGetPropertyDataSize devices failed: \(err)")
            return devices
        }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        err = withUnsafeMutablePointer(to: &deviceIDs[0]) { ptr in
            AudioObjectGetPropertyData(systemObjectID, &propertyAddress, 0, nil, &size, ptr)
        }
        guard err == noErr else {
            Log.debug("AudioObjectGetPropertyData devices failed: \(err)")
            return devices
        }
        for id in deviceIDs where id != 0 {
            let inputChannels = Self.inputChannelCount(deviceID: id)
            guard inputChannels > 0 else { continue }
            let name = Self.deviceName(deviceID: id)
            devices.append(AudioDevice(id: id, name: name, inputChannelCount: inputChannels))
        }
        return devices
    }

    private static func deviceName(deviceID: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let err = withUnsafeMutablePointer(to: &name) { ptr in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, ptr)
        }
        guard err == noErr, let n = name as String? else { return "Device \(deviceID)" }
        return n
    }

    private static func inputChannelCount(deviceID: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        var err = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
        guard err == noErr, size > 0 else { return 0 }
        let bufferListPtr = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferListPtr.deallocate() }
        err = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, bufferListPtr)
        guard err == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(bufferListPtr)
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    static func defaultInputDeviceID() -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let err = withUnsafeMutablePointer(to: &id) { ptr in
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, ptr)
        }
        return err == noErr ? id : 0
    }

    /// Set system default input device (used before starting engine for device switching).
    static func setSystemDefaultInputDevice(id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = id
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let err = withUnsafeMutablePointer(to: &deviceID) { ptr in
            AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, size, ptr)
        }
        return err == noErr
    }

    static func isDeviceSupportedForAUHAL(deviceID: AudioDeviceID) -> Bool {
        let name = deviceName(deviceID: deviceID)
        let lower = name.lowercased()
        return !lower.contains("iphone") && !lower.contains("ipad")
    }

    // MARK: - Device selection

    func setSelectedDevice(id: AudioDeviceID) {
        selectedDeviceID = id
        Log.info("AudioManager: selected device \"\(Self.deviceName(deviceID: id))\" (ID \(id))")
    }

    // MARK: - Capture (AVAudioEngine only)

    private func startEngine() {
        let deviceID = selectedDeviceID ?? Self.defaultInputDeviceID()
        if deviceID != 0, Self.isDeviceSupportedForAUHAL(deviceID: deviceID) {
            let ok = Self.setSystemDefaultInputDevice(id: deviceID)
            if ok {
                Log.info("AudioManager: system default input set to \"\(Self.deviceName(deviceID: deviceID))\"")
            } else {
                Log.debug("AudioManager: could not set default input to device \(deviceID)")
            }
        }
        startAVEngine()
    }

    private func startAVEngine() {
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            Log.error("AudioManager: Invalid input format")
            return
        }
        tapInstallFormat = format
        sampleRate = Float(format.sampleRate)
        analyzer.setSampleRate(sampleRate)

        let pairIdx = selectedChannelPairIndex
        let totalChannels = Int(format.channelCount)
        let ch0 = min(pairIdx * 2, totalChannels - 1)
        let ch1 = min(pairIdx * 2 + 1, totalChannels - 1)

        engine.inputNode.installTap(onBus: 0, bufferSize: kTapBufferSize, format: nil) { [weak self] buffer, _ in
            guard let self = self else { return }
            let frameLength = Int(buffer.frameLength)
            guard let channelData = buffer.floatChannelData, frameLength > 0, frameLength <= self.monoBufferCapacity else { return }

            for i in 0 ..< frameLength {
                let l = channelData[ch0][i]
                let r = totalChannels > 1 ? channelData[ch1][i] : l
                self.monoBuffer[i] = (l + r) * 0.5
            }

            var sumSq: Float = 0
            var peak: Float = 0
            for i in 0 ..< frameLength {
                let s = self.monoBuffer[i]
                sumSq += s * s
                let a = abs(s)
                if a > peak { peak = a }
            }
            let rms = sqrt(sumSq / Float(frameLength))
            self._debugLastRMS = rms
            self._debugLastPeak = peak
            self._debugMaxAbs = peak
            self._debugLastFrames = UInt32(frameLength)

            self.monoBuffer.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return }
                let slice = UnsafeBufferPointer(start: base, count: frameLength)
                self.analyzer.process(buffer: slice)
            }
        }

        do {
            try engine.start()
            Log.info("AudioManager: AVAudioEngine started, \(format.sampleRate) Hz, \(format.channelCount) ch")
        } catch {
            Log.error("AudioManager: AVAudioEngine start failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        if tapInstallFormat != nil {
            engine.inputNode.removeTap(onBus: 0)
            tapInstallFormat = nil
        }
        engine.stop()
        Log.debug("AudioManager: stopped")
    }

    func restartEngine() {
        guard AudioManager.microphonePermissionGranted else { return }
        Log.info("AudioManager: restart requested")
        stop()
        startEngine()
    }

    func setChannelPairIndex(_ index: Int) {
        selectedChannelPairIndex = max(0, index)
        if engine.isRunning {
            restartEngine()
        }
    }

    static var microphonePermissionGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }
}
