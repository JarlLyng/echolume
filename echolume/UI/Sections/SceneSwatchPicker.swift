//
//  SceneSwatchPicker.swift
//  echolume
//
//  Visual scene picker showing a thumbnail per scene instead of a text
//  dropdown — the scene is the biggest look decision, so it deserves the same
//  glanceable treatment as the theme swatches.
//

import IAMJARLDesignTokens
import SwiftUI

struct SceneSwatchPicker: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Scene")
                .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(SceneType.allCases) { scene in
                        Button {
                            appModel.setScene(scene)
                        } label: {
                            SceneSwatch(scene: scene, isSelected: scene == appModel.selectedScene)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(scene.displayName) scene")
                        .accessibilityAddTraits(scene == appModel.selectedScene ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2) // room for the selected ring
            }
        }
    }
}

private struct SceneSwatch: View {
    static let tileWidth: CGFloat = 96
    static let tileHeight: CGFloat = 60
    let scene: SceneType
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            Image(scene.thumbnailAsset)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: Self.tileWidth, height: Self.tileHeight)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .strokeBorder(
                            isSelected ? DesignTokens.Common.primary(colorScheme) : DesignTokens.Common.Border.subtle(colorScheme),
                            lineWidth: isSelected ? 2 : 1
                        )
                )

            Text(scene.displayName)
                .font(.system(size: DesignTokens.Typography.Size.xs, weight: isSelected ? DesignTokens.Typography.Weight.semibold : DesignTokens.Typography.Weight.regular))
                .foregroundStyle(isSelected
                    ? DesignTokens.Common.Text.primary(colorScheme)
                    : DesignTokens.Common.Text.tertiary(colorScheme))
                .lineLimit(1)
        }
    }
}
