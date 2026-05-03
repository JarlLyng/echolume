//
//  ThemeSwatchPicker.swift
//  echolume
//
//  Visual theme picker showing palette swatches instead of a text dropdown.
//  Far better discoverability for a visuals app — users see what they pick.
//

import IAMJARLDesignTokens
import SwiftUI
import simd

struct ThemeSwatchPicker: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Theme")
                .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(Array(ThemeLibrary.themes.enumerated()), id: \.offset) { index, theme in
                        ThemeSwatch(
                            theme: theme,
                            isSelected: index == appModel.selectedThemeIndex
                        )
                        .onTapGesture {
                            appModel.setThemeIndex(index)
                        }
                    }
                }
                .padding(.vertical, 2) // room for selected ring
            }
        }
    }
}

private struct ThemeSwatch: View {
    let theme: Theme
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Palette gradient strip
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(LinearGradient(
                        colors: theme.palette.map { swiftUIColor($0) },
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: 64, height: 40)
            }
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .strokeBorder(
                        isSelected ? DesignTokens.Common.primary(colorScheme) : Color.white.opacity(0.10),
                        lineWidth: isSelected ? 2 : 1
                    )
            )

            Text(theme.name)
                .font(.system(size: DesignTokens.Typography.Size.xs, weight: isSelected ? DesignTokens.Typography.Weight.semibold : DesignTokens.Typography.Weight.regular))
                .foregroundStyle(isSelected
                    ? DesignTokens.Common.Text.primary(colorScheme)
                    : DesignTokens.Common.Text.tertiary(colorScheme))
                .lineLimit(1)
        }
    }

    private func swiftUIColor(_ rgba: SIMD4<Float>) -> Color {
        Color(.sRGB, red: Double(rgba.x), green: Double(rgba.y), blue: Double(rgba.z), opacity: Double(rgba.w))
    }
}
