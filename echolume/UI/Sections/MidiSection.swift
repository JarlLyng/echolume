//
//  MidiSection.swift
//  echolume
//
//  MIDI controller settings: detected inputs, a MIDI Learn toggle, and the
//  note-triggered action bindings. Lives inside Input & Output because a MIDI
//  controller is another input source. Knob (CC) learn happens on the knobs
//  themselves in PerformanceSection.
//

import IAMJARLDesignTokens
import SwiftUI

struct MidiSection: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var midi: MidiManager
    @ObservedObject var mappings: MidiMappingStore
    @Environment(\.colorScheme) private var colorScheme

    init(appModel: AppModel) {
        self.appModel = appModel
        self.midi = appModel.midi
        self.mappings = appModel.midiMappings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("MIDI")
                    .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                Spacer()
                Toggle("Learn", isOn: $appModel.midiLearnActive)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(DesignTokens.Common.primary(colorScheme))
                    .onChange(of: appModel.midiLearnActive) { _, active in
                        if !active { appModel.midiArmedTarget = nil }
                    }
            }

            Text(inputSummary)
                .font(.system(size: DesignTokens.Typography.Size.xs))
                .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))

            if appModel.midiLearnActive {
                Text("Click a knob, then move a control to bind it. Use the buttons below for note triggers.")
                    .font(.system(size: DesignTokens.Typography.Size.xs))
                    .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))

                ForEach(MidiTarget.actions) { action in
                    actionRow(action)
                }
            } else {
                Text("Turn on Learn, then click a knob and move a control to map it. Notes can trigger Randomize, Panic and theme changes.")
                    .font(.system(size: DesignTokens.Typography.Size.xs))
                    .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
            }
        }
        .padding(.top, DesignTokens.Spacing.xs)
    }

    private var inputSummary: String {
        if midi.inputNames.isEmpty {
            return "No MIDI inputs detected"
        }
        return midi.inputNames.joined(separator: ", ")
    }

    private func actionRow(_ action: MidiTarget) -> some View {
        let armed = appModel.midiArmedTarget == action
        let note = mappings.note(for: action)
        return HStack(spacing: DesignTokens.Spacing.sm) {
            Text(action.displayName)
                .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.regular))
                .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
            Spacer()
            Text(armed ? "Listening…" : (note.map { "Note \($0)" } ?? "—"))
                .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                .foregroundStyle(armed ? DesignTokens.Common.primary(colorScheme) : DesignTokens.Common.Text.tertiary(colorScheme))
            Button(armed ? "Cancel" : "Learn") {
                appModel.midiArmedTarget = armed ? nil : action
            }
            .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
            .foregroundStyle(DesignTokens.Common.primary(colorScheme))
            .buttonStyle(.plain)
            if note != nil {
                Button("Clear") { mappings.removeBinding(for: action) }
                    .font(.system(size: DesignTokens.Typography.Size.xs))
                    .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                    .buttonStyle(.plain)
            }
        }
    }
}

extension MidiTarget: Identifiable {
    var id: String { rawValue }
}
