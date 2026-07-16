//
//  SetupBottomBar.swift
//  echolume
//
//  Sticky bottom bar with Panic Reset (left) and Ready CTA (right).
//

import IAMJARLDesignTokens
import SwiftUI

struct SetupBottomBar: View {
    /// Top-shadow styling for the sticky bar (named, not magic — #71).
    private static let shadowOpacity = 0.15
    private static let shadowRadius: CGFloat = 8
    private static let shadowYOffset: CGFloat = -2
    @ObservedObject var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Button(action: { appModel.panicReset() }) {
                Text("Panic Reset")
                    .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.regular))
                    .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.md)
            }
            .buttonStyle(.plain)
            .background(DesignTokens.Common.Background.card(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
            .keyboardShortcut("r", modifiers: [])

            Button(action: { appModel.enterLive() }) {
                Text("Ready")
                    .font(.system(size: DesignTokens.Typography.Size.base, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Spacing.md)
                    .padding(.horizontal, DesignTokens.Spacing.xl)
                    .background(DesignTokens.Common.primary(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [])
            .accessibilityHint("Starts the live visual output")
        }
        .padding(.horizontal, DesignTokens.Spacing.xxl)
        .padding(.vertical, DesignTokens.Spacing.lg)
        .background(
            DesignTokens.Common.Background.app(colorScheme)
                .shadow(color: .black.opacity(Self.shadowOpacity), radius: Self.shadowRadius, y: Self.shadowYOffset)
        )
    }
}
