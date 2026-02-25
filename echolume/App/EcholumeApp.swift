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
    }
}
