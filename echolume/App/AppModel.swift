//
//  AppModel.swift
//  echolume
//

import AVFoundation
import AppKit
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
    @Published var selectedShapeStyle: VisualShapeStyle = .blobs
    @Published var selectedScene: SceneType = .radial
    @Published var energyBias: Float = 0.5
    @Published var motion: Float = 0.5
    @Published var noise: Float = 0.5
    @Published var glitch: Float = 0.2

    private static let userDefaultsShapeStyleKey = "echolume.selectedShapeStyle"
    private static let userDefaultsSceneKey = "echolume.selectedScene"
    private static let userDefaultsMotionKey = "echolume.motion"
    private static let userDefaultsNoiseKey = "echolume.noise"
    private static let userDefaultsGlitchKey = "echolume.glitch"
    private static let userDefaultsSelectedDisplayIDKey = "echolume.selectedDisplayID"

    /// Available displays (main first). Refreshed by refreshDisplays().
    @Published var availableDisplays: [OutputDisplay] = []
    /// Persisted in UserDefaults. Nil = use main-window fullscreen fallback.
    @Published var selectedDisplayID: UUID?
    /// True when Live is shown in a separate window on an external display.
    @Published private(set) var liveOnExternal: Bool = false

    private var liveWindow: NSWindow?
    private let liveWindowDelegate = LiveWindowDelegate()

    @Published var rms: Float = 0
    @Published var peak: Float = 0
    @Published var low: Float = 0
    @Published var mid: Float = 0
    @Published var high: Float = 0
    @Published var impact: Float = 0
    @Published var hasMicPermission: Bool = false
    @Published var audioStatus: AudioStatus = .unknown

    @Published var audioDevices: [AudioDevice] = []
    @Published var selectedDeviceID: AudioDeviceID?
    @Published var showAdvancedDevices: Bool = false
    @Published var selectedChannelPair: Int = 0

    // DEBUG: engine state (updated from timer)
    @Published var debugEngineRunning: Bool = false
    @Published var debugLastError: String?
    @Published var debugFormatSampleRate: Double = 0
    @Published var debugFormatChannelCount: UInt32 = 0
    @Published var debugLastRMS: Float = 0
    @Published var debugLastPeak: Float = 0
    @Published var debugLastFrames: UInt32 = 0
    @Published var debugChannelCount: Int = 0
#if DEBUG
    @Published var debugMaxTapTimeMs: Float = 0
    private var _debugMaxTapTimeReset: CFAbsoluteTime = 0
#endif

    /// Renderer reads from this on its thread; we update from main.
    let visualParamsProvider = VisualParamsProvider()

    private let audioManager = AudioManager()
    private var cancellables = Set<AnyCancellable>()
    private var debugTimer: Timer?

    init() {
        debugTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.debugEngineRunning = self.audioManager.engineRunning
                self.debugLastError = self.audioManager.lastError
                self.debugFormatSampleRate = self.audioManager.formatSampleRate
                self.debugFormatChannelCount = self.audioManager.formatChannelCount
                self.debugLastRMS = self.audioManager.debugLastRMS
                self.debugLastPeak = self.audioManager.debugLastPeak
                self.debugLastFrames = self.audioManager.debugLastFrames
                self.debugChannelCount = self.audioManager.debugChannelCount
                self.rms = self.audioManager.debugLastRMS
                self.peak = self.audioManager.debugLastPeak
                #if DEBUG
                let now = CFAbsoluteTimeGetCurrent()
                if now - self._debugMaxTapTimeReset >= 2.0 {
                    self.debugMaxTapTimeMs = 0
                    self._debugMaxTapTimeReset = now
                }
                let ns = self.audioManager.lastTapDurationNs
                if ns > 0 {
                    let ms = ns / 1_000_000
                    if ms > self.debugMaxTapTimeMs { self.debugMaxTapTimeMs = ms }
                }
                #endif
                self.pushSnapshot()
            }
        }
        RunLoop.main.add(debugTimer!, forMode: .common)
        if let raw = UserDefaults.standard.string(forKey: Self.userDefaultsShapeStyleKey),
           let style = VisualShapeStyle(rawValue: raw) {
            selectedShapeStyle = style
        }
        if let raw = UserDefaults.standard.string(forKey: Self.userDefaultsSceneKey),
           let scene = SceneType(rawValue: raw) {
            selectedScene = scene
        }
        if let v = UserDefaults.standard.object(forKey: Self.userDefaultsMotionKey) as? Double { motion = Float(v) }
        if let v = UserDefaults.standard.object(forKey: Self.userDefaultsNoiseKey) as? Double { noise = Float(v) }
        if let v = UserDefaults.standard.object(forKey: Self.userDefaultsGlitchKey) as? Double { glitch = Float(v) }
        if let uuidString = UserDefaults.standard.string(forKey: Self.userDefaultsSelectedDisplayIDKey),
           let uuid = UUID(uuidString: uuidString) {
            selectedDisplayID = uuid
        }
        refreshDisplays()
        audioManager.lowPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in self?.low = v; self?.pushSnapshot() }
            .store(in: &cancellables)
        audioManager.midPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in self?.mid = v; self?.pushSnapshot() }
            .store(in: &cancellables)
        audioManager.highPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in self?.high = v; self?.pushSnapshot() }
            .store(in: &cancellables)
        audioManager.impactPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in self?.impact = v; self?.pushSnapshot() }
            .store(in: &cancellables)
    }

    private func pushSnapshot() {
        visualParamsProvider.update(
            snapshot: AnalyzerSnapshot(level: rms, peak: peak, low: low, mid: mid, high: high, impact: impact),
            abstraction: abstraction,
            seed: seed,
            themeIndex: selectedThemeIndex,
            shapeStyleIndex: selectedShapeStyle.shaderIndex,
            sceneTypeIndex: selectedScene.shaderIndex,
            energyBias: energyBias,
            motion: motion,
            noise: noise,
            glitch: glitch
        )
    }

    /// Build availableDisplays from NSScreen.screens. Call on app start and when SetupView appears.
    func refreshDisplays() {
        let screens = NSScreen.screens
        availableDisplays = screens.enumerated().map { index, screen in
            OutputDisplay.build(from: screen, isMain: index == 0)
        }
        if availableDisplays.count <= 1 {
            selectedDisplayID = nil
        } else if let id = selectedDisplayID, !availableDisplays.contains(where: { $0.id == id }) {
            selectedDisplayID = nil
        }
    }

    /// Currently selected display, or nil if none / invalid.
    var selectedDisplay: OutputDisplay? {
        guard let id = selectedDisplayID else { return nil }
        return availableDisplays.first { $0.id == id }
    }

    private func enterFullscreenOnMainWindow() {
        state = .live
        liveOnExternal = false
        if let window = NSApp.windows.first(where: { $0.isMainWindow }) {
            window.toggleFullScreen(nil)
        }
    }

    private func exitFullscreenOnMainWindow() {
        if let window = NSApp.windows.first(where: { $0.isMainWindow }), window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
    }

    func enterLive() {
        guard let selected = selectedDisplay else {
            enterFullscreenOnMainWindow()
            return
        }
        if selected.isMain {
            enterFullscreenOnMainWindow()
            return
        }
        let screen = selected.screen
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.level = .mainMenu + 1
        window.collectionBehavior = [.fullScreenPrimary, .canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.contentView = NSHostingView(rootView: LiveView(appModel: self))
        liveWindowDelegate.appModel = self
        window.delegate = liveWindowDelegate
        window.makeKeyAndOrderFront(nil)
        window.toggleFullScreen(nil)
        liveWindow = window
        state = .live
        liveOnExternal = true
    }

    func exitLive() {
        if let w = liveWindow {
            w.close()
            liveWindow = nil
        } else {
            exitFullscreenOnMainWindow()
        }
        liveOnExternal = false
        state = .setup
    }

    /// Called when the external Live window closes (e.g. system or user).
    func externalLiveWindowDidClose() {
        liveWindow = nil
        liveOnExternal = false
        state = .setup
    }

    func setSelectedDisplayID(_ id: UUID?) {
        guard selectedDisplayID != id else { return }
        selectedDisplayID = id
        if let uuid = id {
            UserDefaults.standard.set(uuid.uuidString, forKey: Self.userDefaultsSelectedDisplayIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.userDefaultsSelectedDisplayIDKey)
        }
    }

    /// Enumerate devices on demand. No listeners. Call on appear + refresh button.
    func refreshAudioDevices() {
        audioDevices = AudioDevice.enumerate(includeAdvanced: showAdvancedDevices)
        if selectedDeviceID == nil, let defaultID = systemDefaultInputDeviceID(), audioDevices.contains(where: { $0.id == defaultID }) {
            selectedDeviceID = defaultID
        } else if selectedDeviceID != nil, !audioDevices.contains(where: { $0.id == selectedDeviceID }) {
            selectedDeviceID = audioDevices.first?.id
        }
    }

    private func systemDefaultInputDeviceID() -> AudioDeviceID? {
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
        return err == noErr && id != 0 ? id : nil
    }

    /// Call when app starts or SetupView appears. Requests mic permission; starts engine with selected device.
    func requestMicrophonePermissionAndStartAudio() {
        refreshAudioDevices()
        if selectedDeviceID == nil { selectedDeviceID = audioDevices.first?.id ?? systemDefaultInputDeviceID() }
        audioManager.selectedChannelPairIndex = selectedChannelPair
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            hasMicPermission = true
            audioStatus = .running
            audioManager.restart(withDeviceID: selectedDeviceID)
            pushSnapshot()
        case .denied:
            hasMicPermission = false
            audioStatus = .noPermission
            pushSnapshot()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.hasMicPermission = granted
                    if granted {
                        self.audioStatus = .running
                        self.audioManager.restart(withDeviceID: self.selectedDeviceID)
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

    func selectDevice(id: AudioDeviceID) {
        setSelectedDeviceID(id)
    }

    /// Set device (nil = Automatic / use default when starting).
    func setSelectedDeviceID(_ id: AudioDeviceID?) {
        if selectedDeviceID == id { return }
        selectedDeviceID = id
        if let id = id {
            audioManager.setChannelPairIndex(selectedChannelPair)
            if hasMicPermission { audioManager.restart(withDeviceID: id) }
        }
        pushSnapshot()
    }

    func selectChannelPair(_ index: Int) {
        selectedChannelPair = max(0, index)
        audioManager.setChannelPairIndex(selectedChannelPair)
        if hasMicPermission { audioManager.restart(withDeviceID: selectedDeviceID) }
        pushSnapshot()
    }

    func randomize() {
        seed = UInt32.random(in: 0 ... .max)
        pushSnapshot()
    }

    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens System Settings → Sound (user can switch to Input tab).
    func openAudioSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.sound") {
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

    func setShapeStyle(_ style: VisualShapeStyle) {
        selectedShapeStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: Self.userDefaultsShapeStyleKey)
        pushSnapshot()
    }

    func setScene(_ scene: SceneType) {
        selectedScene = scene
        UserDefaults.standard.set(scene.rawValue, forKey: Self.userDefaultsSceneKey)
        pushSnapshot()
    }

    func setEnergyBias(_ value: Float) {
        energyBias = max(0, min(1, value))
        pushSnapshot()
    }

    func setMotion(_ value: Float) {
        motion = max(0, min(1, value))
        UserDefaults.standard.set(Double(motion), forKey: Self.userDefaultsMotionKey)
        pushSnapshot()
    }

    func setNoise(_ value: Float) {
        noise = max(0, min(1, value))
        UserDefaults.standard.set(Double(noise), forKey: Self.userDefaultsNoiseKey)
        pushSnapshot()
    }

    func setGlitch(_ value: Float) {
        glitch = max(0, min(1, value))
        UserDefaults.standard.set(Double(glitch), forKey: Self.userDefaultsGlitchKey)
        pushSnapshot()
    }
}
