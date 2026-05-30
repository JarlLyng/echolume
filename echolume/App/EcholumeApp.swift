//
//  EcholumeApp.swift
//  echolume
//

import AppKit
import SwiftUI
import Sentry

@main
struct EcholumeApp: App {
    @StateObject private var appModel = AppModel()

    init() {
        if let dsn = ProcessInfo.processInfo.environment["SENTRY_DSN"] ?? Bundle.main.object(forInfoDictionaryKey: "SentryDSN") as? String, !dsn.isEmpty {
            SentrySDK.start { options in
                options.dsn = dsn
                options.environment = ProcessInfo.processInfo.environment["SENTRY_ENVIRONMENT"] ?? (Bundle.main.object(forInfoDictionaryKey: "SentryEnvironment") as? String) ?? "development"
                #if DEBUG
                options.debug = true
                options.tracesSampleRate = 1.0
                #else
                options.tracesSampleRate = 0.2
                #endif
                options.enableAutoSessionTracking = true
            }

            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
            SentrySDK.configureScope { scope in
                scope.setTag(value: "\(version) (\(build))", key: "app_version")
            }

            #if DEBUG
            print("[Sentry] Initialized for Echolume v\(version)")
            #endif
        } else {
            #if DEBUG
            print("[Sentry] No DSN: set SENTRY_DSN env var or SentryDSN in Info.plist")
            #endif
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(appModel: appModel)
                .onAppear {
                    // Restore saved window frame if available; otherwise maximize.
                    // setFrameAutosaveName persists position/size automatically;
                    // on first launch with no saved frame, fall back to maximize.
                    DispatchQueue.main.async {
                        guard let window = NSApplication.shared.windows.first else { return }
                        let autosaveName = "EcholumeMainWindow"
                        let hadSavedFrame = window.setFrameAutosaveName(autosaveName)

                        if !hadSavedFrame {
                            if let screen = window.screen ?? NSScreen.main {
                                window.setFrame(screen.visibleFrame, display: true)
                                window.saveFrame(usingName: autosaveName)
                            }
                            return
                        }

                        // Validate restored frame intersects an attached screen.
                        // If the saved screen was disconnected, fall back to main.
                        let frame = window.frame
                        let onScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
                        if !onScreen, let screen = NSScreen.main {
                            window.setFrame(screen.visibleFrame, display: true)
                        }
                    }
                }
        }
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("Restart Audio") { appModel.restartAudio() }
                    .keyboardShortcut("r", modifiers: .command)
                Button("Panic Reset (Visuals)") { appModel.panicReset() }
                    .keyboardShortcut("r", modifiers: [])
                #if DEBUG
                Divider()
                DebugInspectorMenuButton()
                #endif
            }
        }

        Settings {
            SettingsView(appModel: appModel)
        }

        MenuBarExtra("Echolume", systemImage: "waveform", isInserted: $appModel.menubarEnabled) {
            MenuBarContent(appModel: appModel)
        }

        #if DEBUG
        Window("Debug Inspector", id: "echolume.debug") {
            DebugInspectorView(appModel: appModel)
        }
        .windowResizability(.contentSize)
        #endif
    }
}

#if DEBUG
private struct DebugInspectorMenuButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Show Debug Inspector") {
            openWindow(id: "echolume.debug")
        }
        .keyboardShortcut("d", modifiers: [.command, .shift])
    }
}
#endif

private struct RootView: View {
    @ObservedObject var appModel: AppModel

    /// Show Setup when in setup, or when Live is on external (Setup stays on main).
    private var showSetup: Bool {
        switch appModel.state {
        case .setup: return true
        case .live: return appModel.liveOnExternal
        }
    }

    var body: some View {
        Group {
            if showSetup {
                SetupView(appModel: appModel)
            } else {
                LiveView(appModel: appModel)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appModel.state)
        .animation(.easeInOut(duration: 0.2), value: appModel.liveOnExternal)
        .onKeyPress { key in
            let ch = key.characters
            if key.key == .space { appModel.randomize(); return .handled }
            if key.key == .return {
                if showSetup { appModel.enterLive() } else { appModel.exitLive() }
                return .handled
            }
            // ⌘1…9 recall saved presets 1–9 (no-op if that slot is empty).
            if key.modifiers.contains(.command), let digit = ch.first, let slot = digit.wholeNumberValue,
               (1...9).contains(slot) {
                appModel.applyPreset(atSlot: slot)
                return .handled
            }
            if ch == "1" { appModel.setThemeIndex(0); return .handled }
            if ch == "2" { appModel.setThemeIndex(1); return .handled }
            if ch == "3" { appModel.setThemeIndex(2); return .handled }
            if ch == "4" { appModel.setThemeIndex(3); return .handled }
            if ch == "5" { appModel.setThemeIndex(4); return .handled }
            if ch == "6" { appModel.setThemeIndex(5); return .handled }
            return .ignored
        }
    }
}
