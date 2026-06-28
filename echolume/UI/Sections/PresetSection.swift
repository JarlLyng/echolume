//
//  PresetSection.swift
//  echolume
//
//  Save / recall / delete named visual presets. Full-width section below
//  Performance in SetupView. The first 9 presets are recallable via ⌘1…9.
//

import IAMJARLDesignTokens
import SwiftUI

struct PresetSection: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var store: PresetStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingSaveSheet = false

    init(appModel: AppModel) {
        self.appModel = appModel
        self.store = appModel.presetStore
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("Presets")
                    .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                Spacer()
                Button(action: { showingSaveSheet = true }) {
                    Text("Save current…")
                        .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                        .foregroundStyle(DesignTokens.Common.primary(colorScheme))
                }
                .buttonStyle(.plain)
            }

            if store.presets.isEmpty {
                Text("No presets yet. Dial in a look, then Save current… Recall the first nine with ⌘1–⌘9.")
                    .font(.system(size: DesignTokens.Typography.Size.xs))
                    .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        ForEach(Array(store.presets.enumerated()), id: \.element.id) { index, preset in
                            PresetChip(
                                preset: preset,
                                slot: index < 9 ? index + 1 : nil,
                                onApply: { appModel.apply(preset) },
                                onDelete: { store.delete(id: preset.id) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Common.Background.card(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        .sheet(isPresented: $showingSaveSheet) {
            SavePresetSheet(appModel: appModel, store: store)
        }
    }
}

private struct PresetChip: View {
    let preset: VisualPreset
    let slot: Int?
    let onApply: () -> Void
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Button(action: onApply) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    if let slot {
                        Text("\(slot)")
                            .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.bold))
                            .foregroundStyle(DesignTokens.Common.primary(colorScheme))
                    }
                    Text(preset.name)
                        .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                        .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .help("Apply preset \"\(preset.name)\"" + (slot != nil ? " (⌘\(slot!))" : ""))
            .accessibilityLabel(slot != nil
                ? "Apply preset \(preset.name), shortcut Command \(slot!)"
                : "Apply preset \(preset.name)")

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: DesignTokens.Typography.Size.sm))
                    .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
            }
            .buttonStyle(.plain)
            .help("Delete preset \"\(preset.name)\"")
            .accessibilityLabel("Delete preset \(preset.name)")
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(DesignTokens.Common.Background.app(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .contextMenu {
            Button("Apply", action: onApply)
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

private struct SavePresetSheet: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var store: PresetStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var name = ""

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var validationMessage: String? {
        if trimmed.isEmpty { return nil }
        if store.contains(name: trimmed) { return "A preset named \"\(trimmed)\" already exists." }
        return nil
    }

    private var canSave: Bool {
        !trimmed.isEmpty && validationMessage == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Save preset")
                .font(.system(size: DesignTokens.Typography.Size.lg, weight: DesignTokens.Typography.Weight.bold))
                .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))

            Text("Captures the current theme, shape, scene, and all five knobs.")
                .font(.system(size: DesignTokens.Typography.Size.xs))
                .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))

            TextField("Preset name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit { if canSave { save() } }

            if let validationMessage {
                Text(validationMessage)
                    .font(.system(size: DesignTokens.Typography.Size.xs))
                    .foregroundStyle(DesignTokens.ColorToken.State.error)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(width: 360)
    }

    private func save() {
        guard canSave else { return }
        _ = try? store.add(appModel.captureCurrentPreset(name: trimmed))
        dismiss()
    }
}
