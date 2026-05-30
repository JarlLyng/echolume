//
//  KnobView.swift
//  echolume
//
//  Reusable circular knob: vertical drag (200 px = full range), Option for fine control,
//  double-click resets to defaultValue. Design system colors.
//

import IAMJARLDesignTokens
import SwiftUI
#if os(macOS)
import AppKit
#endif

enum KnobSize {
    case standard  // 64 pt
    case hero      // 88 pt
}

struct KnobView: View {
    let title: String
    @Binding var value: Double
    let defaultValue: Double
    var size: KnobSize = .standard
    var isEnabled: Bool = true
    /// Bound MIDI CC number, shown as a small badge when non-nil.
    var midiCC: Int? = nil
    /// When true, the knob is in MIDI Learn mode: a tap arms it instead of resetting.
    var isLearnMode: Bool = false
    /// When true, this knob is the one currently waiting for a MIDI CC.
    var isArmed: Bool = false
    /// Called when the knob is tapped in MIDI Learn mode.
    var onArm: (() -> Void)? = nil

    private static let dragPixelsFullRange: CGFloat = 200
    private static let fineControlMultiplier: CGFloat = 0.3
    private static let knobSizeStandard: CGFloat = 64
    private static let knobSizeHero: CGFloat = 88
    private static let arcLineWidth: CGFloat = 4
    private static let indicatorLength: CGFloat = 10
    private static let startAngleDegrees: Double = 225
    private static let arcSpanDegrees: Double = 270

    private var knobSize: CGFloat {
        size == .hero ? Self.knobSizeHero : Self.knobSizeStandard
    }

    private var indicatorLength: CGFloat {
        size == .hero ? 14 : 10
    }

    private var arcLineWidth: CGFloat {
        size == .hero ? 5 : 4
    }

    @Environment(\.colorScheme) private var colorScheme
    @State private var dragStartValue: Double = 0
    @State private var dragGestureActive: Bool = false

    private var clampedValue: Double {
        max(0, min(1, value))
    }

    /// Accent ring shown in MIDI Learn mode: solid when armed, subtle when a
    /// CC is already bound.
    @ViewBuilder private var learnRing: some View {
        if isLearnMode {
            Circle()
                .strokeBorder(
                    isArmed ? DesignTokens.Common.primary(colorScheme)
                            : (midiCC != nil ? DesignTokens.Common.primary(colorScheme).opacity(0.4)
                                             : DesignTokens.Common.Border.subtle(colorScheme)),
                    lineWidth: isArmed ? 2 : 1
                )
                .frame(width: knobSize + 8, height: knobSize + 8)
        }
    }

    private var indicatorAngle: Angle {
        .degrees(Self.startAngleDegrees + Self.arcSpanDegrees * clampedValue)
    }

    private var isOptionKeyPressed: Bool {
        #if os(macOS)
        NSEvent.modifierFlags.contains(.option)
        #else
        false
        #endif
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            ZStack {
                // Background arc (full track)
                KnobArcShape(start: 0, end: 1, lineWidth: arcLineWidth)
                    .stroke(
                        DesignTokens.Common.Border.subtle(colorScheme),
                        style: StrokeStyle(lineWidth: arcLineWidth, lineCap: .round)
                    )
                    .frame(width: knobSize, height: knobSize)

                // Filled arc (current value)
                KnobArcShape(start: 0, end: clampedValue, lineWidth: arcLineWidth)
                    .stroke(
                        DesignTokens.Common.primary(colorScheme),
                        style: StrokeStyle(lineWidth: arcLineWidth, lineCap: .round)
                    )
                    .frame(width: knobSize, height: knobSize)

                // Indicator line (from center upward in local coords, then rotated)
                Rectangle()
                    .fill(DesignTokens.Common.primary(colorScheme))
                    .frame(width: size == .hero ? 2.5 : 2, height: indicatorLength)
                    .offset(y: -knobSize / 2 + indicatorLength / 2)
                    .rotationEffect(indicatorAngle)
            }
            .frame(width: knobSize, height: knobSize)
            .overlay(learnRing)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.5)
            .allowsHitTesting(isEnabled)
            .onTapGesture(count: 2) {
                if isEnabled && !isLearnMode { value = max(0, min(1, defaultValue)) }
            }
            .onTapGesture {
                if isEnabled && isLearnMode { onArm?() }
            }
            .gesture(
                DragGesture()
                    .onChanged { g in
                        guard isEnabled, !isLearnMode else { return }
                        if !dragGestureActive {
                            dragGestureActive = true
                            dragStartValue = clampedValue
                        }
                        let sensitivity = isOptionKeyPressed ? Self.fineControlMultiplier : 1.0
                        let delta = -Double(g.translation.height) / Double(Self.dragPixelsFullRange) * Double(sensitivity)
                        value = max(0, min(1, dragStartValue + delta))
                    }
                    .onEnded { _ in
                        dragGestureActive = false
                    }
            )

            if isLearnMode {
                Text(isArmed ? "Listening…" : (midiCC.map { "CC \($0)" } ?? "Tap to bind"))
                    .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(isArmed ? DesignTokens.Common.primary(colorScheme) : DesignTokens.Common.Text.tertiary(colorScheme))
            } else if isEnabled {
                Text(String(format: "%.0f%%", clampedValue * 100))
                    .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.regular))
                    .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
            } else {
                Text("Coming soon")
                    .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.regular))
                    .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
            }

            Text(title)
                .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.semibold))
                .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
        }
        .frame(width: knobSize + DesignTokens.Spacing.lg)
    }
}

// Arc from 0...1 mapped to startAngle..startAngle+span (degrees). Center 0.5,0.5; radius inset by lineWidth.
private struct KnobArcShape: Shape {
    var start: Double
    var end: Double
    var lineWidth: CGFloat = 4

    private static let startAngleDegrees = 225.0
    private static let arcSpanDegrees = 270.0

    func path(in rect: CGRect) -> Path {
        let size = min(rect.width, rect.height)
        let radius = (size / 2) - lineWidth
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let startRad = Angle.degrees(Self.startAngleDegrees + Self.arcSpanDegrees * start).radians
        let endRad = Angle.degrees(Self.startAngleDegrees + Self.arcSpanDegrees * end).radians
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: .radians(startRad), endAngle: .radians(endRad), clockwise: false)
        return path
    }
}

#Preview("Knob") {
    struct Holder: View {
        @State var value: Double = 0.5
        var body: some View {
            HStack(spacing: DesignTokens.Spacing.xl) {
                KnobView(title: "Abstraction", value: $value, defaultValue: 0.5)
                KnobView(title: "Energy", value: $value, defaultValue: 0.5)
            }
            .padding()
        }
    }
    return Holder()
}
