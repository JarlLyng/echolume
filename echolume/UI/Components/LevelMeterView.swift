//
//  LevelMeterView.swift
//  echolume
//
//  Live level meter (RMS + peak) using design tokens.
//

import IAMJARLDesignTokens
import SwiftUI

struct LevelMeterView: View {
    let rms: Float
    let peak: Float
    var compact: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let rmsC = DesignTokens.Common.primary(colorScheme)
        let peakC = DesignTokens.Common.Text.primary(colorScheme)
        let bgC = DesignTokens.Common.Background.muted(colorScheme)
        let h = compact ? 4.0 : 8.0
        let corner = compact ? DesignTokens.Radius.sm / 2 : DesignTokens.Radius.sm

        VStack(alignment: .leading, spacing: compact ? 2 : DesignTokens.Spacing.xs) {
            if !compact {
                Text("Level")
                    .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: corner)
                        .fill(bgC)
                        .frame(height: h)
                    RoundedRectangle(cornerRadius: corner)
                        .fill(rmsC)
                        .frame(width: geo.size.width * CGFloat(rms), height: h)
                    RoundedRectangle(cornerRadius: corner / 2)
                        .fill(peakC)
                        .frame(width: min(geo.size.width, geo.size.width * CGFloat(peak)) + 1, height: h / 2)
                        .offset(y: -h / 4)
                }
            }
            .frame(height: h)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Input level")
        .accessibilityValue("\(Int((min(1, max(0, rms)) * 100).rounded())) percent, peak \(Int((min(1, max(0, peak)) * 100).rounded())) percent")
    }
}

#Preview {
    VStack {
        LevelMeterView(rms: 0.4, peak: 0.7)
            .frame(width: 200, height: 30)
        LevelMeterView(rms: 0.2, peak: 0.3, compact: true)
            .frame(width: 80, height: 14)
    }
    .padding()
}
