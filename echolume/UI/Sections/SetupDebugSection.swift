//
//  DebugInspectorView.swift
//  echolume
//
//  DEBUG-only diagnostics window: band levels, engine state, format,
//  RMS/peak, frames, and tap timing. Opened from the View menu in
//  development builds (Window → Show Debug Inspector, ⇧⌘D).
//  Never shipped to Release / TestFlight.
//

#if DEBUG

import IAMJARLDesignTokens
import SwiftUI

struct DebugInspectorView: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Debug Inspector")
                .font(.system(size: DesignTokens.Typography.Size.lg, weight: DesignTokens.Typography.Weight.bold))
                .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))

            sectionHeader("Audio")
            HStack(spacing: DesignTokens.Spacing.sm) {
                debugLine("L: \(String(format: "%.2f", appModel.low))")
                debugLine("M: \(String(format: "%.2f", appModel.mid))")
                debugLine("H: \(String(format: "%.2f", appModel.high))")
            }
            debugLine("engineRunning: \(appModel.debugEngineRunning ? "true" : "false")")
            if let err = appModel.debugLastError {
                debugLine("lastError: \(err)")
            }
            debugLine("format: \(String(format: "%.0f", appModel.debugFormatSampleRate)) Hz, \(appModel.debugFormatChannelCount) ch")
            debugLine("rms: \(String(format: "%.4f", appModel.debugLastRMS))  peak: \(String(format: "%.4f", appModel.debugLastPeak))")
            debugLine("frames: \(appModel.debugLastFrames)")
            debugLine("tap max (2s): \(String(format: "%.3f", appModel.debugMaxTapTimeMs)) ms")

            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(minWidth: 320, minHeight: 360)
        .background(DesignTokens.Common.Background.app(colorScheme))
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
            .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
            .padding(.top, DesignTokens.Spacing.xs)
    }

    private func debugLine(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
    }
}

#endif
