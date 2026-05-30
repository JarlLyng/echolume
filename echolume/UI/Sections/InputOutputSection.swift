//
//  InputOutputSection.swift
//  echolume
//
//  Audio input device, channel pair, signal indicator, output display,
//  Sound Settings link, and engine error banner. Composed inside SetupView.
//

import CoreAudio
import IAMJARLDesignTokens
import SwiftUI

struct InputOutputSection: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Input & Output")
                .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.semibold))
                .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))

            audioDeviceControls

            if appModel.hasMicPermission {
                signalIndicator
            }

            OutputDisplayPicker(appModel: appModel)

            Button(action: { appModel.openAudioSettings() }) {
                Text("Open Sound Settings")
                    .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.regular))
                    .foregroundStyle(DesignTokens.Common.primary(colorScheme))
            }
            .buttonStyle(.plain)

            if !appModel.debugEngineRunning || appModel.debugLastError != nil {
                engineErrorBanner
            }

            Divider().padding(.vertical, 2)

            // Twitch lives here because it's another input source (chat
            // commands), not a visual style choice.
            TwitchSection(appModel: appModel)

            Divider().padding(.vertical, 2)

            // MIDI is likewise an input source (hardware controller).
            MidiSection(appModel: appModel)

            Divider().padding(.vertical, 2)

            TempoSection(appModel: appModel)

            Divider().padding(.vertical, 2)

            OSCSection(appModel: appModel)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Common.Background.card(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }

    @ViewBuilder
    private var audioDeviceControls: some View {
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
        }
    }

    private var signalIndicator: some View {
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

    private var engineErrorBanner: some View {
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

private struct OutputDisplayPicker: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if !appModel.availableDisplays.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Output Display")
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
