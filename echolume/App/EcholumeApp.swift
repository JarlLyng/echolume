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

    var body: some View {
        Group {
            switch appModel.state {
            case .setup:
                SetupView(appModel: appModel)
            case .live:
                LiveView(appModel: appModel)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appModel.state)
    }
}
