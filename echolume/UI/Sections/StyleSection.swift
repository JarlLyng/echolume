//
//  StyleSection.swift
//  echolume
//
//  Theme swatch picker + Shape/Scene pickers.
//  Twitch lives in Input & Output now (it's an input source, not a visual style).
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

            ThemeSwatchPicker(appModel: appModel)

            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                shapePicker
                scenePicker
                Spacer(minLength: 0)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Common.Background.card(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
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
            .accessibilityLabel("Shape style")
        }
        .frame(width: 170, alignment: .leading)
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
            .accessibilityLabel("Scene")
        }
        .frame(width: 170, alignment: .leading)
    }
}
