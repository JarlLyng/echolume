//
//  ControlSourcesSection.swift
//  echolume
//
//  Groups the non-audio control inputs (Twitch chat, MIDI, tempo/tap, OSC)
//  into one full-width card. They flow into a responsive grid (1–4 columns by
//  width) so they don't overload the narrow Input & Output column and so the
//  layout uses the available horizontal space.
//

import IAMJARLDesignTokens
import SwiftUI

struct ControlSourcesSection: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [GridItem(.adaptive(minimum: 260), spacing: DesignTokens.Spacing.md, alignment: .top)]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Control")
                .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.semibold))
                .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))

            if appModel.showControlOnboarding {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                    Text("New here? Map a hardware controller with MIDI Learn, drive Echolume live over OSC or Twitch chat, and save looks as presets you can recall with ⌘1–⌘9.")
                        .font(.system(size: DesignTokens.Typography.Size.xs))
                        .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Got it") { appModel.dismissControlOnboarding() }
                        .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                        .foregroundStyle(DesignTokens.Common.primary(colorScheme))
                        .buttonStyle(.plain)
                }
                .padding(DesignTokens.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .fill(DesignTokens.Common.primary(colorScheme).opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .strokeBorder(DesignTokens.Common.primary(colorScheme).opacity(0.2), lineWidth: 1)
                )
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: DesignTokens.Spacing.md) {
                tile { TwitchSection(appModel: appModel) }
                tile { MidiSection(appModel: appModel) }
                tile { TempoSection(appModel: appModel) }
                tile { OSCSection(appModel: appModel) }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Common.Background.card(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }

    /// A subtly-filled tile so each control input reads as a distinct cell.
    /// `maxHeight: .infinity` makes every tile fill the grid row's height (set
    /// by the tallest tile) so the cards in a row line up to equal heights.
    private func tile<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(DesignTokens.Spacing.sm)
            .background(DesignTokens.Common.Background.app(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
    }
}
