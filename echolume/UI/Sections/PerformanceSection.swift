//
//  PerformanceSection.swift
//  echolume
//
//  Performance knobs row + Randomize trigger. Full-width section in SetupView.
//

import IAMJARLDesignTokens
import SwiftUI

struct PerformanceSection: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("Performance")
                    .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                Spacer()
                Button(action: { appModel.randomize() }) {
                    Text("Randomize")
                        .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                        .foregroundStyle(DesignTokens.Common.primary(colorScheme))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])
            }

            HStack(spacing: DesignTokens.Spacing.lg) {
                KnobView(
                    title: "Abstraction",
                    value: Binding(
                        get: { Double(appModel.abstraction) },
                        set: { appModel.setAbstraction(Float($0)) }
                    ),
                    defaultValue: 0.5,
                    size: .standard,
                    isEnabled: true
                )
                KnobView(
                    title: "Energy Bias",
                    value: Binding(
                        get: { Double(appModel.energyBias) },
                        set: { appModel.setEnergyBias(Float($0)) }
                    ),
                    defaultValue: 0.5,
                    size: .standard,
                    isEnabled: true
                )
                KnobView(
                    title: "Motion",
                    value: Binding(
                        get: { Double(appModel.motion) },
                        set: { appModel.setMotion(Float($0)) }
                    ),
                    defaultValue: 0.5,
                    size: .standard,
                    isEnabled: true
                )
                KnobView(
                    title: "Noise",
                    value: Binding(
                        get: { Double(appModel.noise) },
                        set: { appModel.setNoise(Float($0)) }
                    ),
                    defaultValue: 0.5,
                    size: .standard,
                    isEnabled: true
                )
                KnobView(
                    title: "Glitch",
                    value: Binding(
                        get: { Double(appModel.glitch) },
                        set: { appModel.setGlitch(Float($0)) }
                    ),
                    defaultValue: 0.2,
                    size: .standard,
                    isEnabled: true
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Common.Background.card(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }
}
