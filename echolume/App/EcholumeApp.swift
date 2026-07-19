//
//  EcholumeApp.swift
//  echolume
//

import AppKit
import StoreKit
import SwiftUI

@main
struct EcholumeApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(appModel: appModel)
                .onAppear {
                    // Restore saved window frame if available; otherwise maximize.
                    // setFrameAutosaveName persists position/size automatically;
                    // on first launch with no saved frame, fall back to maximize.
                    DispatchQueue.main.async {
                        guard let window = NSApplication.shared.windows.first else { return }
                        window.minSize = NSSize(width: 760, height: 620)
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
                        var frame = window.frame
                        let onScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
                        if !onScreen, let screen = NSScreen.main {
                            window.setFrame(screen.visibleFrame, display: true)
                            return
                        }

                        // Opening the app should show the WHOLE Setup UI: a
                        // too-small restored frame (e.g. saved before minSize
                        // existed, or squeezed by an old bug) would clip the
                        // lower sections behind a scroll. Grow it once to the
                        // full-UI size, keeping the top-left corner in place
                        // and staying within the screen.
                        let fullUISize = NSSize(width: 1100, height: 960)
                        if frame.width < fullUISize.width || frame.height < fullUISize.height {
                            let topLeftY = frame.maxY
                            frame.size.width = max(frame.width, fullUISize.width)
                            frame.size.height = max(frame.height, fullUISize.height)
                            frame.origin.y = topLeftY - frame.height
                            // Keep the WHOLE window inside the screen's visible
                            // area (constrainFrameRect only guarantees the title
                            // bar, so a grown window could hang off the bottom).
                            if let screen = window.screen ?? NSScreen.main {
                                let vis = screen.visibleFrame
                                frame.size.width = min(frame.width, vis.width)
                                frame.size.height = min(frame.height, vis.height)
                                frame.origin.x = max(vis.minX, min(frame.origin.x, vis.maxX - frame.width))
                                frame.origin.y = max(vis.minY, min(frame.origin.y, vis.maxY - frame.height))
                            }
                            window.setFrame(frame, display: true)
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
    @Environment(\.requestReview) private var requestReview

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
        .onChange(of: appModel.reviewRequestToken) { _, _ in
            requestReview()
        }
        .onKeyPress { key in
            let ch = key.characters
            // Spacebar = Randomize, but only in Live. On Setup it would nuke a
            // dialed-in look with no undo, so let Space behave normally there.
            if key.key == .space {
                if showSetup { return .ignored }
                appModel.randomize()
                return .handled
            }
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
