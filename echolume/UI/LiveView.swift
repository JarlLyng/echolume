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

            // Overlay: Back + tiny meter
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
                    Spacer()
                    if appModel.hasMicPermission {
                        LevelMeterView(rms: appModel.rms, peak: appModel.peak, compact: true)
                            .frame(width: 80, height: 14)
                    }
                }
                .padding(DesignTokens.Spacing.lg)
                Spacer()
            }

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
