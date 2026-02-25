//
//  SetupView.swift
//  echolume
//

import SwiftUI

struct SetupView: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xl) {
                Text("Echolume")
                    .font(.system(
                        size: DesignTokens.Typography.Size.xxl,
                        weight: DesignTokens.Typography.Weight.bold
                    ))
                    .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))

                // Microphone permission denied
                if !appModel.hasMicPermission && appModel.audioStatus == .noPermission {
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

                // Audio Source picker
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Audio Source")
                        .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.semibold))
                        .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                    if appModel.audioDevices.isEmpty {
                        Text("No input devices found")
                            .font(.system(size: DesignTokens.Typography.Size.sm))
                            .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Picker("", selection: Binding(
                            get: { appModel.selectedDeviceID },
                            set: { if let id = $0 { appModel.selectDevice(id: id) } }
                        )) {
                            ForEach(appModel.audioDevices) { device in
                                Text(device.name).tag(Optional(device.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(DesignTokens.Common.primary(colorScheme))
                    }
                    if appModel.isUnsupportedDeviceSelected {
                        Text("This device is not supported yet.")
                            .font(.system(size: DesignTokens.Typography.Size.xs))
                            .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if appModel.isUsingFallbackInputDevice {
                        Text("Using system default input — selected device could not be used.")
                            .font(.system(size: DesignTokens.Typography.Size.xs))
                            .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Common.Background.card(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))

                // Channel pair picker (stereo pairs for selected device)
                if let device = appModel.audioDevices.first(where: { $0.id == appModel.selectedDeviceID }), !device.channelPairs.isEmpty {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Channel pair")
                            .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.semibold))
                            .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                        Picker("", selection: Binding(
                            get: { min(appModel.selectedChannelPair, device.channelPairs.count - 1) },
                            set: { appModel.selectChannelPair($0) }
                        )) {
                            ForEach(device.channelPairs, id: \.self) { idx in
                                Text(AudioDevice.channelPairLabel(pairIndex: idx)).tag(idx)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(DesignTokens.Common.primary(colorScheme))
                    }
                    .padding(DesignTokens.Spacing.md)
                    .background(DesignTokens.Common.Background.card(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                }

                // Live level meter
                if appModel.hasMicPermission {
                    LevelMeterView(rms: appModel.rms, peak: appModel.peak)
                        .frame(height: 36)
                    #if DEBUG
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Text("L: \(String(format: "%.2f", appModel.low))")
                        Text("M: \(String(format: "%.2f", appModel.mid))")
                        Text("H: \(String(format: "%.2f", appModel.high))")
                    }
                    .font(.system(size: DesignTokens.Typography.Size.xs, weight: .medium))
                    .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("DEBUG AUHAL")
                            .font(.system(size: DesignTokens.Typography.Size.xs, weight: .semibold))
                            .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                        Text("Format flags: 0x\(String(format: "%X", appModel.debugFormatFlags))")
                            .font(.system(size: DesignTokens.Typography.Size.xs))
                            .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                        Text("Interleaved: \(appModel.debugInterleaved ? "true" : "false")")
                            .font(.system(size: DesignTokens.Typography.Size.xs))
                            .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                        Text("BytesPerFrame: \(appModel.debugBytesPerFrame)")
                            .font(.system(size: DesignTokens.Typography.Size.xs))
                            .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                        Text("Channels: \(appModel.debugChannelCount)")
                            .font(.system(size: DesignTokens.Typography.Size.xs))
                            .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                        Text("Frames: \(appModel.debugLastFrames)")
                            .font(.system(size: DesignTokens.Typography.Size.xs))
                            .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                        Text("RMS: \(String(format: "%.4f", appModel.debugLastRMS))")
                            .font(.system(size: DesignTokens.Typography.Size.xs))
                            .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                        Text("MaxAbs: \(String(format: "%.4f", appModel.debugMaxAbs))")
                            .font(.system(size: DesignTokens.Typography.Size.xs))
                            .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                        Text("First sample (ch0): \(String(format: "%.6f", appModel.debugFirstSample))")
                            .font(.system(size: DesignTokens.Typography.Size.xs))
                            .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                        Text("Last render status: \(appModel.debugLastRenderStatus)")
                            .font(.system(size: DesignTokens.Typography.Size.xs))
                            .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Common.Background.card(colorScheme).opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
                    #endif
                }

                // Theme picker
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Theme")
                    .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
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
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Common.Background.card(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))

            // Abstraction slider
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Abstraction")
                    .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                Slider(value: Binding(
                    get: { Double(appModel.abstraction) },
                    set: { appModel.setAbstraction(Float($0)) }
                ), in: 0 ... 1)
                .tint(DesignTokens.Common.primary(colorScheme))
            }

            // Randomize button placeholder
            Button(action: { appModel.randomize() }) {
                Text("Randomize")
                    .font(.system(size: DesignTokens.Typography.Size.base, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Spacing.md)
                    .padding(.horizontal, DesignTokens.Spacing.xl)
                    .background(DesignTokens.Common.Background.card(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                            .stroke(DesignTokens.Common.Border.subtle(colorScheme), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            // Ready button (primary CTA)
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
        }
        .padding(DesignTokens.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Common.Background.app(colorScheme))
        .onAppear { appModel.requestMicrophonePermissionAndStartAudio() }
        }
    }
}

#Preview {
    SetupView(appModel: AppModel())
        .frame(width: 400, height: 500)
}
