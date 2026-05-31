//
//  SetupView.swift
//  echolume
//
//  Setup screen layout shell. Composes section views from UI/Sections/.
//  Two-column on wide windows (Input & Output | Style); stacked when narrow.
//  Performance knobs full-width below. Sticky bottom bar with Panic + Ready.
//

import AppKit
import IAMJARLDesignTokens
import SwiftUI

private let sectionSpacing: CGFloat = DesignTokens.Spacing.md
private let twoColumnBreakpoint: CGFloat = 700

/// Reads the content width so the layout can pick its column count without a
/// GeometryReader container (which would break the ScrollView's height).
private struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct SetupView: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var contentWidth: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                // Content sizes naturally so the ScrollView measures real height
                // and can scroll. Width comes from a background reader (not a
                // GeometryReader container, which would trap the scroll height).
                let narrow = contentWidth < twoColumnBreakpoint
                VStack(spacing: DesignTokens.Spacing.lg) {
                    Text("Echolume")
                        .font(.system(
                            size: DesignTokens.Typography.Size.xxl,
                            weight: DesignTokens.Typography.Weight.bold
                        ))
                        .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))

                    if !appModel.hasMicPermission && appModel.audioStatus == .noPermission {
                        PermissionDeniedCard(appModel: appModel)
                    }

                    if narrow {
                        VStack(alignment: .leading, spacing: sectionSpacing) {
                            InputOutputSection(appModel: appModel)
                            StyleSection(appModel: appModel)
                        }
                    } else {
                        HStack(alignment: .top, spacing: DesignTokens.Spacing.xl) {
                            InputOutputSection(appModel: appModel)
                                .frame(maxWidth: 340, alignment: .leading)
                            StyleSection(appModel: appModel)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    ControlSourcesSection(appModel: appModel)

                    PerformanceSection(appModel: appModel)

                    PresetSection(appModel: appModel)
                }
                .padding(DesignTokens.Spacing.xxl)
                .padding(.bottom, DesignTokens.Spacing.xl)
                .frame(maxWidth: .infinity)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: WidthPreferenceKey.self, value: proxy.size.width)
                    }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onPreferenceChange(WidthPreferenceKey.self) { contentWidth = $0 }

            SetupBottomBar(appModel: appModel)
        }
        .background(DesignTokens.Common.Background.app(colorScheme))
        .onAppear {
            appModel.requestMicrophonePermissionAndStartAudio()
            appModel.refreshDisplays()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            appModel.refreshDisplays()
        }
    }
}

#Preview {
    SetupView(appModel: AppModel())
        .frame(width: 900, height: 700)
}
