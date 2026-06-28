//
//  LiveView.swift
//  echolume
//

import IAMJARLDesignTokens
import SwiftUI

struct LiveView: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme

    // Overlay chrome sits on top of arbitrary Metal output (which can be bright
    // or dark), so it uses fixed scrims + light text for legibility on ANY
    // visuals — colorScheme tokens track the app background, not the canvas.
    private let overlayScrim = Color.black.opacity(0.55)
    private let overlayText = Color.white

    var body: some View {
        ZStack {
            MetalView(
                visualParamsProvider: appModel.visualParamsProvider,
                onError: { [weak appModel] msg in appModel?.setRendererError(msg) }
            )
                .ignoresSafeArea()

            if let err = appModel.rendererError {
                rendererErrorOverlay(err)
            }

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
                    .accessibilityLabel("Exit Live")
                    // Panic is the most important live control — make it the most
                    // prominent, glanceable target (warning-tinted, >=44pt).
                    Button(action: { appModel.panicReset() }) {
                        Text("Panic (R)")
                            .font(.system(size: DesignTokens.Typography.Size.base, weight: DesignTokens.Typography.Weight.semibold))
                            .foregroundStyle(overlayText)
                            .padding(.horizontal, DesignTokens.Spacing.xl)
                            .padding(.vertical, DesignTokens.Spacing.md)
                            .frame(minHeight: 44)
                            .background(DesignTokens.ColorToken.State.warning)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("r", modifiers: [])
                    .accessibilityLabel("Panic reset visuals")
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
                // Centered at the top so it never overlaps the Back button (left)
                // or the level meter (right).
                VStack {
                    VStack(spacing: DesignTokens.Spacing.xs) {
                        Text("NO SIGNAL")
                            .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.bold))
                            .foregroundStyle(DesignTokens.ColorToken.State.warning)
                        Text("Check input device / routing")
                            .font(.system(size: DesignTokens.Typography.Size.xs))
                            .foregroundStyle(overlayText)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(overlayScrim)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 64)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("No audio signal. Check input device or routing.")
            }

            if !appModel.debugEngineRunning {
                VStack {
                    Spacer()
                    Text("Press ⌘R to restart audio")
                        .font(.system(size: DesignTokens.Typography.Size.sm))
                        .foregroundStyle(overlayText)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .background(overlayScrim)
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
                .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                .foregroundStyle(overlayText)
                .padding(DesignTokens.Spacing.sm)
                .background(overlayScrim)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
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

    private func rendererErrorOverlay(_ message: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(DesignTokens.ColorToken.State.warning)
                .accessibilityHidden(true)
            Text("Renderer error")
                .font(.system(size: DesignTokens.Typography.Size.lg, weight: DesignTokens.Typography.Weight.bold))
                .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))
            Text(message)
                .font(.system(size: DesignTokens.Typography.Size.sm))
                .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.xl)
            Button(action: {
                appModel.setRendererError(nil)
                appModel.exitLive()
            }) {
                Text("Back to Setup")
                    .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(DesignTokens.Common.primary(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.Spacing.xxl)
        .background(DesignTokens.Common.Background.card(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
        .shadow(radius: 16)
    }
}

#Preview {
    LiveView(appModel: AppModel())
        .frame(width: 800, height: 600)
}
