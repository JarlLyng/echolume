//
//  PermissionDeniedCard.swift
//  echolume
//
//  Shown when microphone permission is denied. Offers a one-click
//  shortcut to open System Settings → Privacy & Security.
//

import IAMJARLDesignTokens
import SwiftUI

struct PermissionDeniedCard: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Microphone access is required for audio-reactive visuals.")
                .font(.system(size: DesignTokens.Typography.Size.sm))
                .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))
            Button(action: { appModel.openMicrophoneSettings() }) {
                Text("Open System Settings")
                    .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(DesignTokens.Common.primary(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Common.Background.card(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }
}
