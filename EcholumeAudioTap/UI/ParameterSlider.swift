//
//  ParameterSlider.swift
//  EcholumeAudioTap
//
//  Created by Jarl Lyng on 31/05/2026.
//

import SwiftUI

/// A SwiftUI Slider bound to an ObservableAUParameter, styled to match Echolume
/// (lime accent on a dark surface). Shows the parameter name, current value, and
/// the min/max range.
struct ParameterSlider: View {
    @State var param: ObservableAUParameter

    var specifier: String {
        switch param.unit {
        case .midiNoteNumber:
            return "%.0f"
        default:
            return "%.2f"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PluginStyle.Space.sm) {
            HStack {
                Text(param.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PluginStyle.textPrimary)
                Spacer()
                Text("\(param.value, specifier: specifier)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PluginStyle.accent)
            }

            Slider(
                value: $param.value,
                in: param.min...param.max,
                onEditingChanged: param.onEditingChanged
            )
            .tint(PluginStyle.accent)
            .accessibility(identifier: param.displayName)
            .accessibilityLabel(param.displayName)

            HStack {
                Text("\(param.min, specifier: specifier)")
                Spacer()
                Text("\(param.max, specifier: specifier)")
            }
            .font(.system(size: 9))
            .foregroundStyle(PluginStyle.textSecondary)
        }
    }
}
