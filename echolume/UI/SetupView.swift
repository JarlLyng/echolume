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

struct SetupView: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                GeometryReader { geo in
                    let narrow = geo.size.width < twoColumnBreakpoint
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

                        PerformanceSection(appModel: appModel)
                    }
                    .padding(DesignTokens.Spacing.xxl)
                    .padding(.bottom, DesignTokens.Spacing.xl)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, minHeight: 400)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
