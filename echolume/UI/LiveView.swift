//
//  LiveView.swift
//  echolume
//

import SwiftUI

struct LiveView: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            MetalView(visualParamsProvider: appModel.visualParamsProvider)
                .ignoresSafeArea()

            // Overlay: Back + Panic hint + meter
            VStack {
                HStack {
                    Button(action: { appModel.exitLive() }) {
                        Text("Back")
                            .font(.system(size: DesignTokens.Typography.Size.base, weight: DesignTokens.Typography.Weight.semibold))
                            .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
                            .padding(.horizontal, DesignTokens.Spacing.xl)
                            .padding(.vertical, DesignTokens.Spacing.md)
                            .background(DesignTokens.Common.primary(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [])
                    Button(action: { appModel.panicReset() }) {
                        Text("Panic (R)")
                            .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.regular))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("r", modifiers: [])
                    Spacer()
                    if appModel.hasMicPermission {
                        LevelMeterView(rms: appModel.rms, peak: appModel.peak, compact: true)
                            .frame(width: 80, height: 14)
                    }
                }
                .padding(DesignTokens.Spacing.lg)
                Spacer()
            }

            if !appModel.hasSignal {
                VStack {
                    HStack {
                        Text("NO SIGNAL")
                            .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.orange.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
                        Spacer()
                    }
                    HStack {
                        Text("Check input device / routing")
                            .font(.system(size: DesignTokens.Typography.Size.xs))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    Spacer()
                }
                .padding(DesignTokens.Spacing.lg)
            }

            if !appModel.debugEngineRunning {
                VStack {
                    Spacer()
                    Text("Press ⌘R to restart audio")
                        .font(.system(size: DesignTokens.Typography.Size.sm))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
                        .padding(.bottom, 60)
                }
            }

            #if DEBUG
            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Motion: \(String(format: "%.2f", appModel.motion))  Noise: \(String(format: "%.2f", appModel.noise))  Glitch: \(String(format: "%.2f", appModel.glitch))")
                    Text("Impact: \(String(format: "%.2f", appModel.impact))  Peak: \(String(format: "%.2f", appModel.peak))")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .padding(8)
                .background(Color.black.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.bottom, 16)
            }
            #endif
        }
        .background(DesignTokens.Common.Background.app(colorScheme))
        .onExitCommand { appModel.exitLive() }
        .onKeyPress(.escape) {
            appModel.exitLive()
            return .handled
        }
    }
}

#Preview {
    LiveView(appModel: AppModel())
        .frame(width: 800, height: 600)
}
