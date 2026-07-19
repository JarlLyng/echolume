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

    // Twitch
    @Published var twitchEnabled: Bool = false
    @Published var twitchChannelName: String = ""
    @Published var twitchStatus: TwitchConnectionStatus = .disconnected

    /// Set when MetalView reports a Metal device or Renderer init failure.
    /// Surfaced in LiveView so users see a clear message instead of a black screen.
    @Published var rendererError: String?

    /// Called from MetalView. Updates rendererError on the main thread.
    func setRendererError(_ message: String?) {
        rendererError = message
    }

    /// Single source of truth for the UserDefaults keys. Raw values are the
    /// exact legacy strings, so existing users' saved settings still load.
    private enum DefaultsKey: String {
        case shapeStyle = "echolume.selectedShapeStyle"
        case scene = "echolume.selectedScene"
        case motion = "echolume.motion"
        case noise = "echolume.noise"
        case glitch = "echolume.glitch"
        case selectedDisplayID = "echolume.selectedDisplayID"
        case twitchEnabled = "echolume.twitchEnabled"
        case twitchChannel = "echolume.twitchChannel"
        case themeIndex = "echolume.themeIndex"
        case abstraction = "echolume.abstraction"
        case energyBias = "echolume.energyBias"
        case selectedDeviceID = "echolume.selectedDeviceID"
        case selectedChannelPair = "echolume.selectedChannelPair"
        case oscEnabled = "echolume.oscEnabled"
        case oscPort = "echolume.oscPort"
        case menubarEnabled = "echolume.menubarEnabled"
        case meaningfulSessions = "echolume.meaningfulSessions"
        case lastReviewPromptDate = "echolume.lastReviewPromptDate"
        case onboardingDismissed = "echolume.onboardingDismissed"
    }

    /// Persist a settings value. Centralizes the write so setters don't repeat
    /// `UserDefaults.standard.set(_:forKey:)` with literal keys.
    private func persist(_ value: Any, _ key: DefaultsKey) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

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

    /// Signal present (rms > threshold). False after > 2s below threshold.
    @Published var hasSignal: Bool = true
    /// Seconds continuously below threshold (for UX).
    @Published var noSignalSeconds: Double = 0
    /// Seconds above threshold before setting hasSignal true (hysteresis exit).
    private var signalOkSeconds: Double = 0

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

    /// Saved visual presets (theme + shape + scene + 5 knobs). Persisted as JSON.
    let presetStore = PresetStore()

    /// MIDI controller input + persisted CC/note bindings.
    let midi = MidiManager()
    let midiMappings = MidiMappingStore()
    /// When true, the next incoming CC/note binds to `midiArmedTarget`.
    @Published var midiLearnActive = false
    /// The control currently armed for MIDI Learn (nil = none armed).
    @Published var midiArmedTarget: MidiTarget?

    // Tempo / beat tracking
    @Published private(set) var bpm: Float = 0
    @Published private(set) var beatPhase: Float = 0
    @Published private(set) var beatConfidence: Float = 0
    /// When true, tempo is held at the tapped/manual BPM instead of auto-detected.
    @Published private(set) var useManualTempo = false

    // OSC input
    let oscServer = OSCServer()
    @Published private(set) var oscEnabled = false
    @Published private(set) var oscPort: UInt16 = 9000

    /// Timestamp of the last `/echolume/audio/*` packet from the AU plugin.
    /// While recent, plugin audio drives the visuals/signal instead of the mic.
    private var lastPluginAudioTime: CFAbsoluteTime = 0
    var pluginAudioActive: Bool { CFAbsoluteTimeGetCurrent() - lastPluginAudioTime < 0.5 }
    /// Tracks the previous tick's plugin-audio state so we can detect when the
    /// plugin stops feeding us and clear its lingering BPM.
    private var wasPluginAudioActive = false

    /// Whether the menu bar extra is shown. Persisted; default on. Bound by the
    /// Settings toggle; drives the AppKit status item.
    @Published var menubarEnabled = true {
        didSet {
            persist(menubarEnabled, .menubarEnabled)
            menuBarController?.setVisible(menubarEnabled)
        }
    }
    private var menuBarController: MenuBarController?

    private let audioManager = AudioManager()
    private var twitchManager: TwitchChatManager?
    private var twitchStatusCancellable: AnyCancellable?
    private var lastConnectedChannel: String = ""
    private var cancellables = Set<AnyCancellable>()
    private var debugTimer: Timer?
    private var screenParamsObserver: NSObjectProtocol?
    private var deviceListChangeBlock: AudioObjectPropertyListenerBlock?
    private var deviceListPropertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    init() {
        debugTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                // Single atomic read — no race between fields.
                let snap = self.audioManager.snapshot
                self.debugEngineRunning = snap.engineRunning
                self.debugLastError = snap.lastError
                if snap.engineRunning {
                    self.audioStatus = .running
                } else if self.hasMicPermission {
                    self.audioStatus = snap.lastError != nil ? .error(snap.lastError ?? "") : .stopped
                }
                self.debugFormatSampleRate = snap.formatSampleRate
                self.debugFormatChannelCount = snap.formatChannelCount
                self.debugLastRMS = snap.rms
                self.debugLastPeak = snap.peak
                self.debugLastFrames = snap.frameCount
                self.debugChannelCount = snap.channelCount
                // The AU plugin feeds rms directly when active; don't let the
                // mic snapshot override it.
                if !self.pluginAudioActive {
                    self.rms = snap.rms
                    self.peak = snap.peak
                }
                // When the plugin stops feeding audio, don't let its last BPM
                // linger — clear it so the mic beat tracker (or "— BPM") takes
                // over instead of showing a stale tempo.
                let pluginActive = self.pluginAudioActive
                if self.wasPluginAudioActive, !pluginActive {
                    self.bpm = 0
                }
                self.wasPluginAudioActive = pluginActive
                // ~ -46 dBFS: low enough that quiet/ambient mic input registers
                // as signal (the meter already moves at these levels).
                if self.rms > 0.005 {
                    self.noSignalSeconds = 0
                    self.signalOkSeconds += 0.1
                    if self.signalOkSeconds >= 0.5 { self.hasSignal = true }
                } else {
                    self.signalOkSeconds = 0
                    self.noSignalSeconds += 0.1
                    if self.noSignalSeconds > 2.0 { self.hasSignal = false }
                }
                #if DEBUG
                let now = CFAbsoluteTimeGetCurrent()
                if now - self._debugMaxTapTimeReset >= 2.0 {
                    self.debugMaxTapTimeMs = 0
                    self._debugMaxTapTimeReset = now
                }
                let ns = snap.lastTapDurationNs
                if ns > 0 {
                    let ms = ns / 1_000_000
                    if ms > self.debugMaxTapTimeMs { self.debugMaxTapTimeMs = ms }
                }
                #endif
                self.pushSnapshot()
            }
        }
        RunLoop.main.add(debugTimer!, forMode: .common)
        if let raw = UserDefaults.standard.string(forKey: DefaultsKey.shapeStyle.rawValue),
           let style = VisualShapeStyle(rawValue: raw) {
            selectedShapeStyle = style
        }
        if let raw = UserDefaults.standard.string(forKey: DefaultsKey.scene.rawValue),
           let scene = SceneType(rawValue: raw) {
            selectedScene = scene
        }
        if let v = UserDefaults.standard.object(forKey: DefaultsKey.motion.rawValue) as? Double { motion = Float(v) }
        if let v = UserDefaults.standard.object(forKey: DefaultsKey.noise.rawValue) as? Double { noise = Float(v) }
        if let v = UserDefaults.standard.object(forKey: DefaultsKey.glitch.rawValue) as? Double { glitch = Float(v) }
        if let v = UserDefaults.standard.object(forKey: DefaultsKey.abstraction.rawValue) as? Double { abstraction = Float(v) }
        if let v = UserDefaults.standard.object(forKey: DefaultsKey.energyBias.rawValue) as? Double { energyBias = Float(v) }
        if let v = UserDefaults.standard.object(forKey: DefaultsKey.themeIndex.rawValue) as? Int {
            selectedThemeIndex = max(0, min(v, ThemeLibrary.themes.count - 1))
        }
        if let v = UserDefaults.standard.object(forKey: DefaultsKey.selectedDeviceID.rawValue) as? Int, v > 0 {
            // Restore as nil-ish hint; actual device existence is verified once
            // the device list is refreshed below.
            selectedDeviceID = AudioDeviceID(v)
        }
        if let v = UserDefaults.standard.object(forKey: DefaultsKey.selectedChannelPair.rawValue) as? Int {
            selectedChannelPair = max(0, v)
        }
        if let uuidString = UserDefaults.standard.string(forKey: DefaultsKey.selectedDisplayID.rawValue),
           let uuid = UUID(uuidString: uuidString) {
            selectedDisplayID = uuid
        }
        Task { @MainActor in self.refreshDisplays() }
        deviceListChangeBlock = { [weak self] _, _ in
            DispatchQueue.main.async { self?.refreshAudioDevices() }
        }
        if let block = deviceListChangeBlock {
            var addr = deviceListPropertyAddress
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, nil, block)
        }
        screenParamsObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshDisplays() }
        }
        twitchEnabled = UserDefaults.standard.bool(forKey: DefaultsKey.twitchEnabled.rawValue)
        twitchChannelName = UserDefaults.standard.string(forKey: DefaultsKey.twitchChannel.rawValue) ?? ""
        if twitchEnabled && !twitchChannelName.isEmpty {
            connectTwitch()
        }

        // Mic band updates are suppressed while plugin audio is driving.
        audioManager.lowPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in guard let self, !self.pluginAudioActive else { return }; self.low = v; self.pushSnapshot() }
            .store(in: &cancellables)
        audioManager.midPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in guard let self, !self.pluginAudioActive else { return }; self.mid = v; self.pushSnapshot() }
            .store(in: &cancellables)
        audioManager.highPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in guard let self, !self.pluginAudioActive else { return }; self.high = v; self.pushSnapshot() }
            .store(in: &cancellables)
        audioManager.impactPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in self?.impact = v; self?.pushSnapshot() }
            .store(in: &cancellables)

        audioManager.beatPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] beat in
                guard let self, !self.pluginAudioActive else { return }
                self.bpm = beat.bpm
                self.beatPhase = beat.beatPhase
                self.beatConfidence = beat.confidence
                self.pushSnapshot()
            }
            .store(in: &cancellables)

        audioManager.spectrumPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bins in
                // Like the band publishers above: the local input's spectrum
                // must not overwrite the plugin's bins while it is driving.
                guard let self, !self.pluginAudioActive else { return }
                self.visualParamsProvider.updateSpectrum(bins)
            }
            .store(in: &cancellables)

        midi.onMessage = { [weak self] msg in self?.handleMidi(msg) }
        midi.start()

        if let p = UserDefaults.standard.object(forKey: DefaultsKey.oscPort.rawValue) as? Int, p > 0, p <= 65535 {
            oscPort = UInt16(p)
        }
        oscEnabled = UserDefaults.standard.bool(forKey: DefaultsKey.oscEnabled.rawValue)
        oscServer.onMessage = { [weak self] msg in self?.handleOSC(msg) }
        if oscEnabled { oscServer.start(port: oscPort) }

        if UserDefaults.standard.object(forKey: DefaultsKey.menubarEnabled.rawValue) != nil {
            menubarEnabled = UserDefaults.standard.bool(forKey: DefaultsKey.menubarEnabled.rawValue)
        }
        // Create the status item unless launched by the UI test harness (a menu
        // bar extra blocks XCUITest's accessibility handshake).
        if ProcessInfo.processInfo.environment["ECHOLUME_UITEST"] != "1" {
            let controller = MenuBarController(appModel: self)
            controller.setVisible(menubarEnabled)
            menuBarController = controller
        }
    }

    /// Bring the main window forward (from the menu bar extra while fullscreen
    /// on another display).
    func showMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    deinit {
        if let block = deviceListChangeBlock {
            var addr = deviceListPropertyAddress
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, nil, block)
        }
    }

    private func pushSnapshot() {
        visualParamsProvider.update(
            snapshot: AnalyzerSnapshot(level: rms, peak: peak, low: low, mid: mid, high: high, impact: impact, bpm: bpm, beatPhase: beatPhase),
            abstraction: abstraction,
            seed: seed,
            themeIndex: selectedThemeIndex,
            shapeStyleIndex: selectedShapeStyle.shaderIndex,
            sceneTypeIndex: selectedScene.shaderIndex,
            energyBias: energyBias,
            motion: motion,
            noise: noise,
            glitch: glitch,
            hasSignal: hasSignal
        )
    }

    /// Panic reset: new seed, reset glitch/impulse transients. Does not restart audio.
    func panicReset() {
        seed = UInt32.random(in: 0 ... .max)
        visualParamsProvider.requestTransientReset()
        pushSnapshot()
    }

    /// Restart audio engine with current device and channel pair.
    func restartAudio() {
        audioManager.setChannelPairIndex(selectedChannelPair)
        audioManager.restart(withDeviceID: selectedDeviceID)
    }

    /// Build availableDisplays from NSScreen.screens. Call on app start and when SetupView appears. Closes live window if its display was disconnected.
    func refreshDisplays() {
        let screens = NSScreen.screens
        if let w = liveWindow, let screen = w.screen, !screens.contains(where: { $0 === screen }) {
            w.close()
            liveWindow = nil
            liveOnExternal = false
            state = .setup
        }
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

    // MARK: - First-run onboarding

    /// Shown once (until dismissed) to point new users at the advanced control
    /// features that are otherwise easy to miss (MIDI Learn, presets, OSC/Twitch).
    @Published var showControlOnboarding = !UserDefaults.standard.bool(forKey: DefaultsKey.onboardingDismissed.rawValue)

    func dismissControlOnboarding() {
        showControlOnboarding = false
        UserDefaults.standard.set(true, forKey: DefaultsKey.onboardingDismissed.rawValue)
    }

    // MARK: - App Store review prompt

    /// Bumped when a review request should be shown. A SwiftUI view observes
    /// this and calls the RequestReviewAction (which itself rate-limits and may
    /// choose not to show the prompt).
    @Published private(set) var reviewRequestToken = 0

    /// Wall-clock start of the current Live session (nil when not live).
    private var liveEnteredAt: CFAbsoluteTime?

    /// A "meaningful" Live session lasts at least this long — a real
    /// performance, not an accidental Ready → Back. Only these count.
    private let kMeaningfulSessionSeconds: CFAbsoluteTime = 90
    /// Ask for a review only after this many meaningful sessions…
    private let kSessionsBeforeReview = 3
    /// …and never more often than this (Apple also caps at ~3/year).
    private let kMinDaysBetweenPrompts: Double = 120

    /// Called from `exitLive()`. If the session was long enough, count it and,
    /// once the thresholds are met, ask a SwiftUI view to request a review on a
    /// positive moment (never at launch).
    private func maybePromptReviewAfterSession() {
        guard let start = liveEnteredAt else { return }
        guard CFAbsoluteTimeGetCurrent() - start >= kMeaningfulSessionSeconds else { return }

        let defaults = UserDefaults.standard
        let sessions = defaults.integer(forKey: DefaultsKey.meaningfulSessions.rawValue) + 1
        defaults.set(sessions, forKey: DefaultsKey.meaningfulSessions.rawValue)
        guard sessions >= kSessionsBeforeReview else { return }

        let now = Date().timeIntervalSince1970
        let last = defaults.double(forKey: DefaultsKey.lastReviewPromptDate.rawValue)
        guard last == 0 || now - last > kMinDaysBetweenPrompts * 86_400 else { return }

        defaults.set(now, forKey: DefaultsKey.lastReviewPromptDate.rawValue)
        reviewRequestToken += 1
    }

    func enterLive() {
        liveEnteredAt = CFAbsoluteTimeGetCurrent()
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
        maybePromptReviewAfterSession()
        liveEnteredAt = nil
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
            persist(uuid.uuidString, .selectedDisplayID)
        } else {
            UserDefaults.standard.removeObject(forKey: DefaultsKey.selectedDisplayID.rawValue)
        }
    }

    /// Enumerate devices. Updates automatically when hardware changes (CoreAudio listener).
    func refreshAudioDevices() {
        audioDevices = AudioDevice.enumerate(includeAdvanced: showAdvancedDevices)
        if selectedDeviceID == nil, let defaultID = systemDefaultInputDeviceID(), audioDevices.contains(where: { $0.id == defaultID }) {
            selectedDeviceID = defaultID
        } else if selectedDeviceID != nil, !audioDevices.contains(where: { $0.id == selectedDeviceID }) {
            // Vanished device: prefer the system default input over the first
            // list entry — alphabetical order can land on a silent loopback
            // driver (e.g. "BlackHole 2ch"), which reads as a "No signal" bug.
            selectedDeviceID = systemDefaultInputDeviceID() ?? audioDevices.first?.id
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
        // Prefer the system default input; alphabetical first-in-list can be a
        // silent loopback driver (e.g. "BlackHole 2ch") — see #109.
        if selectedDeviceID == nil { selectedDeviceID = systemDefaultInputDeviceID() ?? audioDevices.first?.id }
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
        case .restricted:
            hasMicPermission = false
            audioStatus = .noPermission
            pushSnapshot()
        @unknown default:
            hasMicPermission = false
            audioStatus = .noPermission
            pushSnapshot()
        }
    }

    func selectDevice(id: AudioDeviceID) {
        setSelectedDeviceID(id)
    }

    /// Set device (nil = Automatic / use system default).
    func setSelectedDeviceID(_ id: AudioDeviceID?) {
        if selectedDeviceID == id { return }
        selectedDeviceID = id
        if let id {
            persist(Int(id), .selectedDeviceID)
        } else {
            UserDefaults.standard.removeObject(forKey: DefaultsKey.selectedDeviceID.rawValue)
        }
        audioManager.setChannelPairIndex(selectedChannelPair)
        if hasMicPermission { audioManager.restart(withDeviceID: id) }
        pushSnapshot()
    }

    func selectChannelPair(_ index: Int) {
        selectedChannelPair = max(0, index)
        persist(selectedChannelPair, .selectedChannelPair)
        audioManager.setChannelPairIndex(selectedChannelPair)
        if hasMicPermission { audioManager.restart(withDeviceID: selectedDeviceID) }
        pushSnapshot()
    }

    /// Randomize theme, shape, scene, and seed in one go. Picks a different
    /// theme and scene than the current ones when possible so the change is
    /// always visible. The README and Twitch guide promise this — !randomize
    /// in chat triggers the same path.
    func randomize() {
        seed = UInt32.random(in: 0 ... .max)   // intentionally not persisted

        // Route through the setters so persistence/clamping live in one place
        // (no duplicated UserDefaults writes here).
        let themeCount = ThemeLibrary.themes.count
        if themeCount > 1 {
            var idx = Int.random(in: 0 ..< themeCount)
            if idx == selectedThemeIndex {
                idx = (idx + 1) % themeCount
            }
            setThemeIndex(idx)   // also resets shape to the theme default…
        }

        // …then pick a random allowed shape, overriding that default.
        let theme = ThemeLibrary.theme(byIndex: selectedThemeIndex)
        if let shape = theme.allowedShapeStyles.randomElement() {
            setShapeStyle(shape)
        }

        let scenes = SceneType.allCases
        if scenes.count > 1, var newScene = scenes.randomElement() {
            if newScene == selectedScene {
                newScene = scenes.first(where: { $0 != selectedScene }) ?? newScene
            }
            setScene(newScene)
        }

        // Randomize the performance knobs too (the button lives in Performance).
        // Knobs span a musical mid-range; glitch is kept lower so it isn't always heavy.
        setAbstraction(Float.random(in: 0.2 ... 0.9))
        setEnergyBias(Float.random(in: 0.2 ... 0.9))
        setMotion(Float.random(in: 0.2 ... 0.9))
        setNoise(Float.random(in: 0.2 ... 0.9))
        setGlitch(Float.random(in: 0.0 ... 0.5))

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

    /// When user changes theme, apply its default shape style and push to provider.
    func setThemeIndex(_ index: Int) {
        selectedThemeIndex = max(0, min(index, ThemeLibrary.themes.count - 1))
        persist(selectedThemeIndex, .themeIndex)
        let theme = ThemeLibrary.theme(byIndex: selectedThemeIndex)
        selectedShapeStyle = theme.defaultShapeStyle
        persist(selectedShapeStyle.rawValue, .shapeStyle)
        pushSnapshot()
    }

    func setAbstraction(_ value: Float) {
        abstraction = max(0, min(1, value))
        persist(Double(abstraction), .abstraction)
        pushSnapshot()
    }

    func setShapeStyle(_ style: VisualShapeStyle) {
        selectedShapeStyle = style
        persist(style.rawValue, .shapeStyle)
        pushSnapshot()
    }

    func setScene(_ scene: SceneType) {
        selectedScene = scene
        persist(scene.rawValue, .scene)
        pushSnapshot()
    }

    func setEnergyBias(_ value: Float) {
        energyBias = max(0, min(1, value))
        persist(Double(energyBias), .energyBias)
        pushSnapshot()
    }

    func setMotion(_ value: Float) {
        motion = max(0, min(1, value))
        persist(Double(motion), .motion)
        pushSnapshot()
    }

    func setNoise(_ value: Float) {
        noise = max(0, min(1, value))
        persist(Double(noise), .noise)
        pushSnapshot()
    }

    func setGlitch(_ value: Float) {
        glitch = max(0, min(1, value))
        persist(Double(glitch), .glitch)
        pushSnapshot()
    }

    // MARK: - Presets

    /// Snapshot the current visual state under `name` (not yet stored).
    func captureCurrentPreset(name: String) -> VisualPreset {
        VisualPreset(
            name: name,
            themeIndex: selectedThemeIndex,
            shapeStyle: selectedShapeStyle.rawValue,
            scene: selectedScene.rawValue,
            abstraction: abstraction,
            energyBias: energyBias,
            motion: motion,
            noise: noise,
            glitch: glitch
        )
    }

    /// Apply a preset by routing through the existing setters, so persistence
    /// and the render snapshot update exactly as if the user moved each control.
    /// Note: `setThemeIndex` resets shape to the theme default, so it must run
    /// before the shape is applied.
    func apply(_ preset: VisualPreset) {
        setThemeIndex(preset.themeIndex)
        if let style = VisualShapeStyle(rawValue: preset.shapeStyle) {
            setShapeStyle(style)
        }
        if let scene = SceneType(rawValue: preset.scene) {
            setScene(scene)
        }
        setAbstraction(preset.abstraction)
        setEnergyBias(preset.energyBias)
        setMotion(preset.motion)
        setNoise(preset.noise)
        setGlitch(preset.glitch)
    }

    /// Recall the preset in the given 1-based slot (keyboard ⌘1…9). No-op if empty.
    func applyPreset(atSlot slot: Int) {
        if let preset = presetStore.preset(atSlot: slot) {
            apply(preset)
        }
    }

    /// Recall a preset by name (Twitch `!preset <name>`). No-op if not found.
    func applyPreset(named name: String) {
        if let preset = presetStore.preset(named: name) {
            apply(preset)
        }
    }

    // MARK: - MIDI

    /// Route an incoming MIDI message: in Learn mode bind it to the armed
    /// target; otherwise apply it through the persisted mappings.
    private func handleMidi(_ msg: MidiMessage) {
        if midiLearnActive, let target = midiArmedTarget {
            switch msg {
            case .controlChange(_, let cc, _) where target.isKnob:
                midiMappings.bind(target: target, kind: .cc, number: cc)
                midiArmedTarget = nil
            case .noteOn(_, let note, _) where !target.isKnob:
                midiMappings.bind(target: target, kind: .note, number: note)
                midiArmedTarget = nil
            default:
                break // wrong message type for the armed target — keep waiting
            }
            return
        }

        switch msg {
        case .controlChange(_, let cc, let value):
            if let target = midiMappings.target(forCC: cc) {
                applyKnobTarget(target, value: midiValueToUnit(value))
            }
        case .noteOn(_, let note, _):
            if let target = midiMappings.target(forNote: note) {
                applyActionTarget(target)
            }
        }
    }

    private func applyKnobTarget(_ target: MidiTarget, value: Float) {
        switch target {
        case .abstraction: setAbstraction(value)
        case .energyBias: setEnergyBias(value)
        case .motion: setMotion(value)
        case .noise: setNoise(value)
        case .glitch: setGlitch(value)
        default: break
        }
    }

    private func applyActionTarget(_ target: MidiTarget) {
        switch target {
        case .randomize: randomize()
        case .panic: panicReset()
        case .nextTheme: nextTheme()
        case .previousTheme: previousTheme()
        case .tapTempo: tapTempo()
        default: break
        }
    }

    // MARK: - Tempo

    /// Register a tap-tempo tap. Switches tempo to manual hold.
    func tapTempo() {
        useManualTempo = true
        audioManager.tapTempo()
    }

    /// Toggle between auto-detected tempo and a held manual/tapped tempo.
    func setUseManualTempo(_ on: Bool) {
        useManualTempo = on
        audioManager.setManualBPM(on ? (bpm > 0 ? bpm : nil) : nil)
    }

    // MARK: - OSC

    func setOSCEnabled(_ on: Bool) {
        oscEnabled = on
        persist(on, .oscEnabled)
        if on { oscServer.start(port: oscPort) } else { oscServer.stop() }
    }

    func setOSCPort(_ port: UInt16) {
        guard port > 0 else { return }
        oscPort = port
        persist(Int(port), .oscPort)
        if oscEnabled { oscServer.start(port: port) }   // restart on the new port
    }

    /// Apply an incoming OSC message via the fixed /echolume/... namespace.
    private func handleOSC(_ message: OSCMessage) {
        // Audio from the AU plugin drives the visuals/signal directly.
        if message.address.hasPrefix("/echolume/audio/") {
            handlePluginAudio(message)
            return
        }
        guard let action = OSCAction(message: message) else { return }
        applyOSCAction(action)
    }

    /// Feed plugin audio analysis (`/echolume/audio/{level,low,mid,high,bpm,spectrum}`)
    /// directly into the visual pipeline + signal detection.
    private func handlePluginAudio(_ message: OSCMessage) {
        // Full 64-bin spectrum frame for per-bin scenes (Spectrum Ring,
        // Ridgeline). The plugin sends the same shaped 0…1 bins the app's own
        // analyzer produces, so no re-normalization is needed here.
        if message.address == "/echolume/audio/spectrum" {
            var bins = [Float]()
            bins.reserveCapacity(message.arguments.count)
            for arg in message.arguments {
                switch arg {
                case .float(let f): bins.append(max(0, min(1, f)))
                case .int(let i): bins.append(max(0, min(1, Float(i))))
                default: return
                }
            }
            guard !bins.isEmpty else { return }
            lastPluginAudioTime = CFAbsoluteTimeGetCurrent()
            visualParamsProvider.updateSpectrum(bins)
            return
        }

        let v: Float
        switch message.arguments.first {
        case .float(let f): v = f
        case .int(let i): v = Float(i)
        default: return
        }
        lastPluginAudioTime = CFAbsoluteTimeGetCurrent()
        switch message.address {
        case "/echolume/audio/level": rms = max(0, min(1, v)); peak = rms
        case "/echolume/audio/low": low = max(0, min(1, v))
        case "/echolume/audio/mid": mid = max(0, min(1, v))
        case "/echolume/audio/high": high = max(0, min(1, v))
        case "/echolume/audio/bpm": bpm = max(0, v)
        default: return
        }
        pushSnapshot()
    }

    private func applyOSCAction(_ action: OSCAction) {
        switch action {
        case .abstraction(let v): setAbstraction(v)
        case .energyBias(let v): setEnergyBias(v)
        case .motion(let v): setMotion(v)
        case .noise(let v): setNoise(v)
        case .glitch(let v): setGlitch(v)
        case .theme(let i): setThemeIndex(i)
        case .scene(let i): setScene(SceneType.allCases[max(0, min(SceneType.allCases.count - 1, i))])
        case .shape(let i): setShapeStyle(VisualShapeStyle.allCases[max(0, min(VisualShapeStyle.allCases.count - 1, i))])
        case .randomize: randomize()
        case .panic: panicReset()
        case .nextTheme: nextTheme()
        case .prevTheme: previousTheme()
        case .tapTempo: tapTempo()
        case .presetSlot(let n): applyPreset(atSlot: n)
        case .presetName(let name): applyPreset(named: name)
        }
    }

    /// Advance to the next theme, wrapping around.
    func nextTheme() {
        let count = ThemeLibrary.themes.count
        guard count > 0 else { return }
        setThemeIndex((selectedThemeIndex + 1) % count)
    }

    /// Go to the previous theme, wrapping around.
    func previousTheme() {
        let count = ThemeLibrary.themes.count
        guard count > 0 else { return }
        setThemeIndex((selectedThemeIndex - 1 + count) % count)
    }

    // MARK: - Twitch

    func setTwitchEnabled(_ enabled: Bool) {
        twitchEnabled = enabled
        persist(enabled, .twitchEnabled)
        if enabled && !twitchChannelName.isEmpty {
            connectTwitch()
        } else if !enabled {
            disconnectTwitch()
        }
    }

    /// Updates the channel name and persists it. Connection is managed via the
    /// Connect button (or Enable toggle) — not on every keystroke.
    func setTwitchChannel(_ name: String) {
        twitchChannelName = name
        persist(name, .twitchChannel)
        if name.isEmpty {
            disconnectTwitch()
        }
    }

    func connectTwitch() {
        let target = twitchChannelName
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard !target.isEmpty else { return }

        // No-op if already connecting/connected to the same channel.
        if target == lastConnectedChannel {
            switch twitchStatus {
            case .connected, .connecting: return
            default: break
            }
        }

        // Tear down any existing manager and its status subscription before
        // creating a new one to avoid subscription leaks on reconnect.
        twitchStatusCancellable?.cancel()
        twitchStatusCancellable = nil
        twitchManager?.disconnect()

        let manager = TwitchChatManager()
        manager.onCommand = { [weak self] cmd in
            self?.handleTwitchCommand(cmd)
        }
        twitchStatusCancellable = manager.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] s in self?.twitchStatus = s }

        twitchManager = manager
        lastConnectedChannel = target
        manager.connect(channel: target)
    }

    func disconnectTwitch() {
        twitchStatusCancellable?.cancel()
        twitchStatusCancellable = nil
        twitchManager?.disconnect()
        twitchManager = nil
        twitchStatus = .disconnected
        lastConnectedChannel = ""
    }

    private func handleTwitchCommand(_ cmd: TwitchCommand) {
        switch cmd {
        case .theme(let name):
            if let idx = ThemeLibrary.themes.firstIndex(where: {
                $0.name.lowercased() == name.lowercased()
            }) { setThemeIndex(idx) }
        case .randomize:
            randomize()
        case .scene(let name):
            if let scene = SceneType.allCases.first(where: {
                $0.rawValue.lowercased() == name.lowercased()
            }) { setScene(scene) }
        case .shape(let name):
            if let style = VisualShapeStyle.allCases.first(where: {
                $0.rawValue.lowercased() == name.lowercased()
            }) { setShapeStyle(style) }
        case .glitch:
            setGlitch(glitch > 0.5 ? 0.2 : 1.0)
        case .abstract(let pct):
            setAbstraction(Float(pct) / 100.0)
        case .preset(let name):
            applyPreset(named: name)
        }
    }
}
