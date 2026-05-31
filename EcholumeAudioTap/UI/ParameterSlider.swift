//
//  ParameterSlider.swift
//  EcholumeAudioTap
//
//  Created by Jarl Lyng on 31/05/2026.
//

import SwiftUI

/// A SwiftUI Slider container which is bound to an ObservableAUParameter
///
/// This view wraps a SwiftUI Slider, and provides it relevant data from the Parameter, like the minimum and maximum values.
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
        // Note: the EcholumeAudioTap AUv3 extension intentionally does NOT link
        // the IAMJARLDesignTokens SPM package (keeps the app-extension lean; the
        // AU host controls view sizing). UI here uses plain SwiftUI with
        // consistent spacing instead of design tokens.
        VStack(spacing: 8) {
            Slider(
                value: $param.value,
                in: param.min...param.max,
                onEditingChanged: param.onEditingChanged,
                minimumValueLabel: Text("\(param.min, specifier: specifier)"),
                maximumValueLabel: Text("\(param.max, specifier: specifier)")
            ) {
                EmptyView()
            }
            .accessibility(identifier: param.displayName)
            .accessibilityLabel(param.displayName)
            Text("\(param.displayName): \(param.value, specifier: specifier)")
                .font(.system(size: 12, weight: .medium))
        }
        .padding(16)
    }
}
