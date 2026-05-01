//
//  SetupDebugSection.swift
//  echolume
//
//  DEBUG-only collapsible diagnostics: band levels, engine state,
//  format, RMS/peak, frames, and tap timing.
//

#if DEBUG

import IAMJARLDesignTokens
import SwiftUI

struct SetupDebugSection: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text("L: \(String(format: "%.2f", appModel.low))")
                    Text("M: \(String(format: "%.2f", appModel.mid))")
                    Text("H: \(String(format: "%.2f", appModel.high))")
                }
                .font(.system(size: DesignTokens.Typography.Size.xs))
                .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))

                debugLine("engineRunning: \(appModel.debugEngineRunning ? "true" : "false")")
                if let err = appModel.debugLastError {
                    debugLine("lastError: \(err)")
                }
                debugLine("format: \(String(format: "%.0f", appModel.debugFormatSampleRate)) Hz, \(appModel.debugFormatChannelCount) ch")
                debugLine("rms: \(String(format: "%.4f", appModel.debugLastRMS))  peak: \(String(format: "%.4f", appModel.debugLastPeak))")
                debugLine("frames: \(appModel.debugLastFrames)")
                debugLine("tap max (2s): \(String(format: "%.3f", appModel.debugMaxTapTimeMs)) ms")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.sm)
        } label: {
            Text("Debug")
                .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
        }
        .padding(DesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Common.Background.card(colorScheme).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
    }

    private func debugLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: DesignTokens.Typography.Size.xs))
            .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
    }
}

#endif
