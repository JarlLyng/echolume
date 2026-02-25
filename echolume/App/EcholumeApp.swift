//
//  EcholumeApp.swift
//  echolume
//

import SwiftUI

@main
struct EcholumeApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(appModel: appModel)
        }
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("Restart Audio") { appModel.restartAudio() }
                    .keyboardShortcut("r", modifiers: .command)
                Button("Panic Reset (Visuals)") { appModel.panicReset() }
                    .keyboardShortcut("r", modifiers: [])
            }
        }
    }
}

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
