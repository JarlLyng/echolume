//
//  StyleSection.swift
//  echolume
//
//  Theme/Shape/Scene pickers and the embedded compact Twitch chat panel.
//

import IAMJARLDesignTokens
import SwiftUI

struct StyleSection: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Style")
                .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.semibold))
                .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))

            HStack(spacing: DesignTokens.Spacing.md) {
                themePicker
                shapePicker
                scenePicker
            }

            TwitchSection(appModel: appModel)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Common.Background.card(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Theme")
                .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
            Picker("", selection: Binding(
                get: { appModel.selectedThemeIndex },
                set: { appModel.setThemeIndex($0) }
            )) {
                ForEach(Array(ThemeLibrary.themes.enumerated()), id: \.offset) { index, theme in
                    Text(theme.name).tag(index)
                }
            }
            .pickerStyle(.menu)
            .tint(DesignTokens.Common.primary(colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var shapePicker: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Shape")
                .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
            let theme = ThemeLibrary.theme(byIndex: appModel.selectedThemeIndex)
            Picker("", selection: Binding(
                get: { appModel.selectedShapeStyle },
                set: { appModel.setShapeStyle($0) }
            )) {
                ForEach(theme.allowedShapeStyles) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.menu)
            .tint(DesignTokens.Common.primary(colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scenePicker: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Scene")
                .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
            Picker("", selection: Binding(
                get: { appModel.selectedScene },
                set: { appModel.setScene($0) }
            )) {
                ForEach(SceneType.allCases) { scene in
                    Text(scene.displayName).tag(scene)
                }
            }
            .pickerStyle(.menu)
            .tint(DesignTokens.Common.primary(colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
