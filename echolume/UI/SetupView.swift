//
//  SetupView.swift
//  echolume
//
//  Two-column Mac-native layout: Audio (left), Visuals (right). Ready at bottom.
//

import AppKit
import CoreAudio
import SwiftUI

private let sectionSpacing: CGFloat = DesignTokens.Spacing.md
private let twoColumnBreakpoint: CGFloat = 700

struct SetupView: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme
    #if DEBUG
    @State private var debugExpanded: Bool = false
    #endif

    var body: some View {
        ScrollView {
            GeometryReader { geo in
                let narrow = geo.size.width < twoColumnBreakpoint
                VStack(spacing: DesignTokens.Spacing.lg) {
                    Text("Echolume")
                        .font(.system(
                            size: DesignTokens.Typography.Size.xxl,
                            weight: DesignTokens.Typography.Weight.bold
                        ))
                        .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))

                    if !appModel.hasMicPermission && appModel.audioStatus == .noPermission {
                        permissionDeniedCard
                    }

                    if narrow {
                        VStack(alignment: .leading, spacing: sectionSpacing) {
                            audioSection
                            visualsColumn
                        }
                    } else {
                        HStack(alignment: .top, spacing: DesignTokens.Spacing.xl) {
                            audioSection
                                .frame(maxWidth: 320, alignment: .leading)
                            visualsColumn
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    readySection

                    #if DEBUG
                    debugSection
                    #endif
                }
                .padding(DesignTokens.Spacing.xxl)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, minHeight: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Common.Background.app(colorScheme))
        .onAppear {
            appModel.requestMicrophonePermissionAndStartAudio()
            appModel.refreshDisplays()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            appModel.refreshDisplays()
        }
    }

    // MARK: - Audio (left column)
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Audio")
                .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.semibold))
                .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))

            if appModel.audioDevices.isEmpty {
                Text("No input devices")
                    .font(.system(size: DesignTokens.Typography.Size.sm))
                    .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
            } else {
                Picker("", selection: Binding(
                    get: { appModel.selectedDeviceID },
                    set: { appModel.setSelectedDeviceID($0) }
                )) {
                    Text("Automatic").tag(nil as AudioDeviceID?)
                    ForEach(appModel.audioDevices) { device in
                        Text(device.name).tag(Optional(device.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(DesignTokens.Common.primary(colorScheme))

                if appModel.debugChannelCount >= 2 {
                    let pairCount = appModel.debugChannelCount / 2
                    Picker("Channel pair", selection: Binding(
                        get: { min(appModel.selectedChannelPair, max(0, pairCount - 1)) },
                        set: { appModel.selectChannelPair($0) }
                    )) {
                        ForEach(0 ..< pairCount, id: \.self) { idx in
                            Text(AudioDevice.channelPairLabel(pairIndex: idx)).tag(idx)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(DesignTokens.Common.primary(colorScheme))
                }

                if let err = appModel.debugLastError, !err.isEmpty {
                    Text(err)
                        .font(.system(size: DesignTokens.Typography.Size.xs))
                        .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                }

                Button(action: { appModel.openAudioSettings() }) {
                    Text("Open Sound Settings")
                        .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.regular))
                        .foregroundStyle(DesignTokens.Common.primary(colorScheme))
                }
                .buttonStyle(.plain)
            }

            if appModel.hasMicPermission {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: appModel.hasSignal ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: DesignTokens.Typography.Size.sm))
                        .foregroundStyle(appModel.hasSignal ? DesignTokens.Common.primary(colorScheme) : DesignTokens.ColorToken.State.warning)
                    Text(appModel.hasSignal ? "Signal" : "No signal")
                        .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.regular))
                        .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                    Spacer()
                    LevelMeterView(rms: appModel.rms, peak: appModel.peak, compact: true)
                        .frame(width: 60, height: 14)
                }
            }

            if !appModel.debugEngineRunning || appModel.debugLastError != nil {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(DesignTokens.ColorToken.State.warning)
                    Text(appModel.debugLastError ?? "Audio not running")
                        .font(.system(size: DesignTokens.Typography.Size.xs))
                        .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                    Spacer()
                    Button("Restart audio (⌘R)") { appModel.restartAudio() }
                        .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                        .foregroundStyle(DesignTokens.Common.primary(colorScheme))
                }
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Common.Background.card(colorScheme).opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Common.Background.card(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }

    // MARK: - Visuals (right column)
    private var visualsColumn: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            Text("Visuals")
                .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.semibold))
                .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))

            HStack(spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Theme")
                        .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                        .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                    Picker("", selection: Binding(
                        get: { appModel.selectedThemeIndex },
                        set: { appModel.setThemeIndex($0) }
                    )) {
                        ForEach(Array(ThemeLibrary.themes.enumerated()), id: \.offset) { index, theme in
                            Text(theme.name).tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(DesignTokens.Common.primary(colorScheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

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
                }
                .frame(maxWidth: .infinity, alignment: .leading)

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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            outputDisplaySection

            // Knobs: 2 rows horizontal
            HStack(spacing: DesignTokens.Spacing.lg) {
                KnobView(
                    title: "Abstraction",
                    value: Binding(
                        get: { Double(appModel.abstraction) },
                        set: { appModel.setAbstraction(Float($0)) }
                    ),
                    defaultValue: 0.5,
                    size: .standard,
                    isEnabled: true
                )
                KnobView(
                    title: "Energy Bias",
                    value: Binding(
                        get: { Double(appModel.energyBias) },
                        set: { appModel.setEnergyBias(Float($0)) }
                    ),
                    defaultValue: 0.5,
                    size: .standard,
                    isEnabled: true
                )
            }
            HStack(spacing: DesignTokens.Spacing.lg) {
                KnobView(
                    title: "Motion",
                    value: Binding(
                        get: { Double(appModel.motion) },
                        set: { appModel.setMotion(Float($0)) }
                    ),
                    defaultValue: 0.5,
                    size: .standard,
                    isEnabled: true
                )
                KnobView(
                    title: "Noise",
                    value: Binding(
                        get: { Double(appModel.noise) },
                        set: { appModel.setNoise(Float($0)) }
                    ),
                    defaultValue: 0.5,
                    size: .standard,
                    isEnabled: true
                )
                KnobView(
                    title: "Glitch",
                    value: Binding(
                        get: { Double(appModel.glitch) },
                        set: { appModel.setGlitch(Float($0)) }
                    ),
                    defaultValue: 0.2,
                    size: .standard,
                    isEnabled: true
                )
            }

            HStack(spacing: DesignTokens.Spacing.md) {
                Button(action: { appModel.randomize() }) {
                    Text("Randomize")
                        .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.semibold))
                        .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])

                Button(action: { appModel.panicReset() }) {
                    Text("Panic")
                        .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.regular))
                        .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("r", modifiers: [])
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Common.Background.card(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }

    private var outputDisplaySection: some View {
        Group {
            if !appModel.availableDisplays.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Output")
                        .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                        .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                    if appModel.availableDisplays.count <= 1 {
                        Picker("", selection: Binding(
                            get: { appModel.selectedDisplayID },
                            set: { appModel.setSelectedDisplayID($0) }
                        )) {
                            Text("Main Display").tag(nil as UUID?)
                            ForEach(appModel.availableDisplays) { display in
                                Text(display.name).tag(display.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(DesignTokens.Common.primary(colorScheme))
                        .disabled(true)
                    } else {
                        Picker("", selection: Binding(
                            get: { appModel.selectedDisplayID },
                            set: { appModel.setSelectedDisplayID($0) }
                        )) {
                            Text("Automatic (Main)").tag(nil as UUID?)
                            ForEach(appModel.availableDisplays) { display in
                                Text("\(display.name) — \(display.resolution)")
                                    .tag(display.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(DesignTokens.Common.primary(colorScheme))
                    }
                }
            }
        }
    }

    private var readySection: some View {
        Button(action: { appModel.enterLive() }) {
            Text("Ready")
                .font(.system(size: DesignTokens.Typography.Size.base, weight: DesignTokens.Typography.Weight.semibold))
                .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.md)
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .background(DesignTokens.Common.primary(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.return, modifiers: [])
    }

    // MARK: - Permission denied
    private var permissionDeniedCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Microphone access is required for audio-reactive visuals.")
                .font(.system(size: DesignTokens.Typography.Size.sm))
                .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))
            Button(action: { appModel.openMicrophoneSettings() }) {
                Text("Open System Settings")
                    .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(DesignTokens.Common.primary(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Common.Background.card(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }

    // MARK: - Debug (DEBUG only)
    #if DEBUG
    private var debugSection: some View {
        DisclosureGroup(isExpanded: $debugExpanded) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text("L: \(String(format: "%.2f", appModel.low))")
                    Text("M: \(String(format: "%.2f", appModel.mid))")
                    Text("H: \(String(format: "%.2f", appModel.high))")
                }
                .font(.system(size: DesignTokens.Typography.Size.xs))
                .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))

                Text("engineRunning: \(appModel.debugEngineRunning ? "true" : "false")")
                    .font(.system(size: DesignTokens.Typography.Size.xs))
                    .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                if let err = appModel.debugLastError {
                    Text("lastError: \(err)")
                        .font(.system(size: DesignTokens.Typography.Size.xs))
                        .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                }
                Text("format: \(String(format: "%.0f", appModel.debugFormatSampleRate)) Hz, \(appModel.debugFormatChannelCount) ch")
                    .font(.system(size: DesignTokens.Typography.Size.xs))
                    .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                Text("rms: \(String(format: "%.4f", appModel.debugLastRMS))  peak: \(String(format: "%.4f", appModel.debugLastPeak))")
                    .font(.system(size: DesignTokens.Typography.Size.xs))
                    .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                Text("frames: \(appModel.debugLastFrames)")
                    .font(.system(size: DesignTokens.Typography.Size.xs))
                    .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                Text("tap max (2s): \(String(format: "%.3f", appModel.debugMaxTapTimeMs)) ms")
                    .font(.system(size: DesignTokens.Typography.Size.xs))
                    .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.sm)
        } label: {
            Text("Debug")
                .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
        }
        .padding(DesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Common.Background.card(colorScheme).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
    }
    #endif
}

#Preview {
    SetupView(appModel: AppModel())
        .frame(width: 900, height: 700)
}
