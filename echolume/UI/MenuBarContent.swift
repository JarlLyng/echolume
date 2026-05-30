//
//  MenuBarContent.swift
//  echolume
//
//  Settings pane (⌘,). The menu bar extra itself is an AppKit NSStatusItem
//  (see MenuBarController) because SwiftUI's MenuBarExtra can't be omitted
//  under UI test and trips the SceneBuilder compiler.
//

import SwiftUI

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
