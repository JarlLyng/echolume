//
//  EcholumeAudioTapMainView.swift
//  EcholumeAudioTap
//
//  Created by Jarl Lyng on 31/05/2026.
//

import SwiftUI

struct EcholumeAudioTapMainView: View {
    var parameterTree: ObservableAUParameterGroup

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: PluginStyle.Space.lg) {
            header

            // Gain control card
            ParameterSlider(param: parameterTree.global.gain)
                .padding(PluginStyle.Space.lg)
                .background(PluginStyle.surface)
                .clipShape(RoundedRectangle(cornerRadius: PluginStyle.radius))
                .overlay(
                    RoundedRectangle(cornerRadius: PluginStyle.radius)
                        .strokeBorder(PluginStyle.border, lineWidth: 1)
                )

            Spacer(minLength: 0)

            Text("Forwards analysed bands + host BPM to Echolume over OSC (port 9000). Audio passes through unchanged.")
                .font(.system(size: 10))
                .foregroundStyle(PluginStyle.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(PluginStyle.Space.xl)
        .frame(minWidth: 280, minHeight: 200, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PluginStyle.background)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var header: some View {
        HStack(spacing: PluginStyle.Space.sm) {
            // "Active" dot — gently pulses (static if reduce-motion is on).
            Circle()
                .fill(PluginStyle.accent)
                .frame(width: 8, height: 8)
                .opacity(reduceMotion ? 1.0 : (pulse ? 1.0 : 0.35))
                .shadow(color: PluginStyle.accent.opacity(0.7), radius: pulse && !reduceMotion ? 5 : 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PluginStyle.Space.xs) {
                Text("ECHOLUME")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(PluginStyle.textPrimary)
                Text("AUDIO TAP")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(PluginStyle.accent)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Echolume Audio Tap")
    }
}
