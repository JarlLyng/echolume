//
//  MenuBarContent.swift
//  echolume
//
//  Menu bar extra: quick actions + live status, reachable while Echolume runs
//  fullscreen on another display. Also a small Settings pane with the toggle
//  to hide the icon.
//

import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        // Status (non-interactive).
        Text(appModel.hasSignal ? "Audio: signal" : "Audio: no signal")
        Text("Twitch: \(twitchStatusText)")
        if appModel.bpm > 0 {
            Text(String(format: "Tempo: %.0f BPM", appModel.bpm))
        }

        Divider()

        Button("Randomize") { appModel.randomize() }
        Button("Panic Reset") { appModel.panicReset() }
        Button("Restart Audio") { appModel.restartAudio() }

        Divider()

        Button("Open Echolume") { appModel.showMainWindow() }
        Button("Quit Echolume") { NSApplication.shared.terminate(nil) }
    }

    private var twitchStatusText: String {
        switch appModel.twitchStatus {
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .error: return "error"
        }
    }
}

/// Preferences pane (⌘,). Currently just the menu bar toggle; a natural home
/// for future app-level preferences.
struct SettingsView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        Form {
            Toggle("Show menu bar icon", isOn: $appModel.menubarEnabled)
        }
        .padding(20)
        .frame(width: 320)
    }
}
