//
//  TempoSection.swift
//  echolume
//
//  Tempo readout + tap-tempo control. Shows detected BPM with a lock dot,
//  a Tap button (also bindable to a MIDI note), and an Auto/Manual toggle.
//  Lives in Input & Output alongside the other input sources.
//

import IAMJARLDesignTokens
import SwiftUI

struct TempoSection: View {
    /// Status-dot diameter (named, not magic — #71).
    private static let statusDotSize: CGFloat = 6
    @ObservedObject var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text("Tempo")
                    .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))

                Circle()
                    .fill(lockColor)
                    .frame(width: Self.statusDotSize, height: Self.statusDotSize)

                Text(bpmLabel)
                    .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))

                Spacer()

                Button("Tap") { appModel.tapTempo() }
                    .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(DesignTokens.Common.primary(colorScheme))
                    .buttonStyle(.plain)

                Toggle("Manual", isOn: Binding(
                    get: { appModel.useManualTempo },
                    set: { appModel.setUseManualTempo($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(DesignTokens.Common.primary(colorScheme))
                .fixedSize()
            }
        }
        .padding(.top, DesignTokens.Spacing.xs)
    }

    private var bpmLabel: String {
        appModel.bpm > 0 ? String(format: "%.0f BPM", appModel.bpm) : "— BPM"
    }

    /// Green when locked with confidence, amber when tracking, gray when no signal.
    private var lockColor: Color {
        if appModel.useManualTempo { return DesignTokens.Common.primary(colorScheme) }
        if appModel.bpm <= 0 { return DesignTokens.Common.Text.tertiary(colorScheme) }
        return appModel.beatConfidence > 0.3
            ? DesignTokens.ColorToken.State.success
            : DesignTokens.ColorToken.State.warning
    }
}
