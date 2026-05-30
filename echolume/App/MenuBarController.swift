//
//  MenuBarController.swift
//  echolume
//
//  AppKit NSStatusItem menu bar extra: quick actions + live status, reachable
//  while Echolume runs fullscreen on another display. Implemented in AppKit
//  (not SwiftUI's MenuBarExtra) so it can be omitted entirely under UI test and
//  toggled at runtime without tripping the SceneBuilder compiler.
//

import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private weak var appModel: AppModel?
    private var statusItem: NSStatusItem?

    init(appModel: AppModel) {
        self.appModel = appModel
        super.init()
    }

    /// Show or hide the status item.
    func setVisible(_ visible: Bool) {
        if visible { show() } else { hide() }
    }

    private func show() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Echolume")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    private func hide() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    // Rebuild the menu each time it opens so status lines reflect live state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let appModel else { return }
        menu.removeAllItems()
        menu.addItem(status(appModel.hasSignal ? "Audio: signal" : "Audio: no signal"))
        menu.addItem(status("Twitch: \(twitchText(appModel.twitchStatus))"))
        if appModel.bpm > 0 {
            menu.addItem(status(String(format: "Tempo: %.0f BPM", appModel.bpm)))
        }
        menu.addItem(.separator())
        menu.addItem(action("Randomize", #selector(doRandomize)))
        menu.addItem(action("Panic Reset", #selector(doPanic)))
        menu.addItem(action("Restart Audio", #selector(doRestart)))
        menu.addItem(.separator())
        menu.addItem(action("Open Echolume", #selector(doOpen)))
        menu.addItem(action("Quit Echolume", #selector(doQuit)))
    }

    private func status(_ title: String) -> NSMenuItem {
        // action == nil → auto-disabled (grey, non-interactive status line).
        NSMenuItem(title: title, action: nil, keyEquivalent: "")
    }

    private func action(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }

    private func twitchText(_ status: TwitchConnectionStatus) -> String {
        switch status {
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .error: return "error"
        }
    }

    @objc private func doRandomize() { appModel?.randomize() }
    @objc private func doPanic() { appModel?.panicReset() }
    @objc private func doRestart() { appModel?.restartAudio() }
    @objc private func doOpen() { appModel?.showMainWindow() }
    @objc private func doQuit() { NSApplication.shared.terminate(nil) }
}
