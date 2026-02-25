//
//  AppModel.swift
//  echolume
//

import AVFoundation
import Combine
import CoreAudio
import Foundation
import SwiftUI

enum AppState {
    case setup
    case live
}

enum AudioStatus: Equatable {
    case unknown
    case noPermission
    case running
    case stopped
    case error(String)
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state: AppState = .setup

    @Published var selectedThemeIndex: Int = 0
    @Published var abstraction: Float = 0.5
    @Published var seed: UInt32 = 0

    @Published var audioDevices: [AudioDevice] = []
    @Published var selectedDeviceID: AudioDeviceID?
    @Published var selectedChannelPair: Int = 0
    @Published var rms: Float = 0
    @Published var peak: Float = 0
    @Published var low: Float = 0
    @Published var mid: Float = 0
    @Published var high: Float = 0
    @Published var hasMicPermission: Bool = false
    @Published var audioStatus: AudioStatus = .unknown
    /// True when the selected input device could not be used and system default is used instead.
    @Published private(set) var isUsingFallbackInputDevice: Bool = false
    /// True when the user selected an unsupported device (e.g. iPhone mic); show "This device is not supported yet".
    @Published private(set) var isUnsupportedDeviceSelected: Bool = false

    // DEBUG: AUHAL and callback state (updated from timer)
    @Published var debugAUHALRunning: Bool = false
    @Published var debugLastRMS: Float = 0
    @Published var debugLastPeak: Float = 0
    @Published var debugLastRenderStatus: Int = 0
    @Published var debugChannelCount: Int = 0
    @Published var debugLastFrames: UInt32 = 0
    @Published var debugFirstSample: Float = 0
    @Published var debugMaxAbs: Float = 0
    @Published var debugFormatFlags: UInt32 = 0
    @Published var debugBytesPerFrame: UInt32 = 0
    @Published var debugInterleaved: Bool = false

    /// Renderer reads from this on its thread; we update from main.
    let visualParamsProvider = VisualParamsProvider()

    private let audioManager = AudioManager()
    private var cancellables = Set<AnyCancellable>()
    private var debugTimer: Timer?

    init() {
        debugTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.debugAUHALRunning = self.audioManager.isAUHALActive
                self.debugLastRMS = self.audioManager.debugLastRMS
                self.debugLastPeak = self.audioManager.debugLastPeak
                self.debugLastRenderStatus = Int(self.audioManager.debugLastRenderStatus)
                self.debugChannelCount = self.audioManager.debugChannelCount
                self.debugLastFrames = self.audioManager.debugLastFrames
                self.debugFirstSample = self.audioManager.debugFirstSample
                self.debugMaxAbs = self.audioManager.debugMaxAbs
                self.debugFormatFlags = self.audioManager.debugFormatFlags
                self.debugBytesPerFrame = self.audioManager.debugBytesPerFrame
                self.debugInterleaved = self.audioManager.debugInterleaved
            }
        }
        RunLoop.main.add(debugTimer!, forMode: .common)

        audioManager.onFallbackToDefaultDevice = { [weak self] in
            Task { @MainActor in
                self?.isUsingFallbackInputDevice = true
            }
        }
        audioManager.rmsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in
                self?.rms = v
                self?.pushSnapshot()
            }
            .store(in: &cancellables)
        audioManager.peakPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in
                self?.peak = v
                self?.pushSnapshot()
            }
            .store(in: &cancellables)
        audioManager.lowPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in
                self?.low = v
                self?.pushSnapshot()
            }
            .store(in: &cancellables)
        audioManager.midPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in
                self?.mid = v
                self?.pushSnapshot()
            }
            .store(in: &cancellables)
        audioManager.highPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in
                self?.high = v
                self?.pushSnapshot()
            }
            .store(in: &cancellables)
    }

    private func pushSnapshot() {
        visualParamsProvider.update(
            snapshot: AnalyzerSnapshot(level: rms, peak: peak, low: low, mid: mid, high: high),
            abstraction: abstraction,
            seed: seed,
            themeIndex: selectedThemeIndex
        )
    }

    /// Call when app starts or SetupView appears. Requests microphone permission if needed;
    /// only starts AudioManager after permission is granted.
    func requestMicrophonePermissionAndStartAudio() {
        audioDevices = AudioManager.enumerateInputDevices()
        if selectedDeviceID == nil {
            selectedDeviceID = preferredDefaultDeviceID()
        }

        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            hasMicPermission = true
            audioStatus = .running
            isUsingFallbackInputDevice = false
            if let id = selectedDeviceID { audioManager.setSelectedDevice(id: id) }
            audioManager.selectedChannelPairIndex = selectedChannelPair
            audioManager.restartEngine()
            pushSnapshot()

        case .denied:
            hasMicPermission = false
            audioStatus = .noPermission
            pushSnapshot()

        case .notDetermined:
            // This is the only path that triggers the system permission dialog and
            // adds the app to System Settings → Privacy & Security → Microphone.
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.hasMicPermission = granted
                    if granted {
                        self.audioStatus = .running
                        self.isUsingFallbackInputDevice = false
                        if let id = self.selectedDeviceID { self.audioManager.setSelectedDevice(id: id) }
                        self.audioManager.selectedChannelPairIndex = self.selectedChannelPair
                        self.audioManager.restartEngine()
                    } else {
                        self.audioStatus = .noPermission
                    }
                    self.pushSnapshot()
                }
            }

        @unknown default:
            hasMicPermission = false
            audioStatus = .noPermission
            pushSnapshot()
        }
    }

    func enterLive() {
        state = .live
    }

    func exitLive() {
        state = .setup
    }

    func randomize() {
        seed = UInt32.random(in: 0 ... .max)
        pushSnapshot()
    }

    /// Preferred default: MacBook mic by name, else system default input, else first supported device.
    private func preferredDefaultDeviceID() -> AudioDeviceID? {
        let defaultID = AudioManager.defaultInputDeviceID()
        if let macBook = audioDevices.first(where: { $0.name.localizedCaseInsensitiveContains("MacBook") && $0.isSupportedForAUHAL }) {
            return macBook.id
        }
        if defaultID != 0, audioDevices.contains(where: { $0.id == defaultID }) {
            return defaultID
        }
        if let supported = audioDevices.first(where: { $0.isSupportedForAUHAL }) {
            return supported.id
        }
        return audioDevices.first?.id
    }

    func selectDevice(id: AudioDeviceID) {
        selectedDeviceID = id
        isUnsupportedDeviceSelected = audioDevices.first(where: { $0.id == id }).map { !$0.isSupportedForAUHAL } ?? false
        audioManager.setSelectedDevice(id: id)
        if hasMicPermission {
            audioManager.restartEngine()
        }
    }

    func selectChannelPair(_ index: Int) {
        selectedChannelPair = max(0, index)
        audioManager.setChannelPairIndex(selectedChannelPair)
    }

    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    var selectedTheme: Theme {
        ThemeLibrary.theme(byIndex: selectedThemeIndex)
    }

    /// When user changes theme or abstraction, push to provider.
    func setThemeIndex(_ index: Int) {
        selectedThemeIndex = max(0, min(index, ThemeLibrary.themes.count - 1))
        pushSnapshot()
    }

    func setAbstraction(_ value: Float) {
        abstraction = max(0, min(1, value))
        pushSnapshot()
    }
}
