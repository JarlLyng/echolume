//
//  ExternalDisplaySupport.swift
//  echolume
//
//  OutputDisplay enumeration and Live window delegate.
//

import AppKit
import SwiftUI

// MARK: - Output Display

struct OutputDisplay: Identifiable {
    let id: UUID
    let screen: NSScreen
    let name: String
    let resolution: String
    var isMain: Bool { screen == NSScreen.screens.first }

    /// Deterministic UUID from screen number so the same display keeps the same id across refresh.
    static func build(from screen: NSScreen, isMain: Bool) -> OutputDisplay {
        let raw = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uintValue ?? 0
        let screenNumber = UInt32(truncatingIfNeeded: raw)
        let id = deterministicUUID(for: screenNumber)
        let width = Int(screen.frame.width)
        let height = Int(screen.frame.height)
        let baseName = screen.localizedName
        let name = isMain ? "\(baseName) (Main)" : baseName
        let resolution = "\(width)×\(height)"
        return OutputDisplay(id: id, screen: screen, name: name, resolution: resolution)
    }

    private static func deterministicUUID(for screenNumber: UInt32) -> UUID {
        let key = "echolume.display.\(screenNumber)"
        var bytes = Array(key.utf8)
        while bytes.count < 16 { bytes.append(contentsOf: key.utf8) }
        let b = bytes.prefix(16)
        return UUID(uuid: (
            b[b.startIndex], b[b.startIndex + 1], b[b.startIndex + 2], b[b.startIndex + 3],
            b[b.startIndex + 4], b[b.startIndex + 5], b[b.startIndex + 6], b[b.startIndex + 7],
            b[b.startIndex + 8], b[b.startIndex + 9], b[b.startIndex + 10], b[b.startIndex + 11],
            b[b.startIndex + 12], b[b.startIndex + 13], b[b.startIndex + 14], b[b.startIndex + 15]
        ))
    }
}

// MARK: - Live window delegate

/// Forwards window close to AppModel so state stays in sync when the Live window is closed by the system.
final class LiveWindowDelegate: NSObject, NSWindowDelegate {
    weak var appModel: AppModel?

    func windowWillClose(_ notification: Notification) {
        appModel?.externalLiveWindowDidClose()
    }
}
