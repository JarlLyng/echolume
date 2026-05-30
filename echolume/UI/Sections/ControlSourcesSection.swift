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
    private func tile<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.sm)
            .background(DesignTokens.Common.Background.app(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
    }
}
