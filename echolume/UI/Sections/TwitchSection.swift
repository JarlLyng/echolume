//
//  TwitchSection.swift
//  echolume
//
//  Compact Twitch chat panel embedded inside the Style card.
//  Toggle, channel field, Connect/Disconnect button, and status indicator.
//

import IAMJARLDesignTokens
import SwiftUI

struct TwitchSection: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text("Twitch Chat")
                    .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))

                Spacer()

                Toggle(isOn: Binding(
                    get: { appModel.twitchEnabled },
                    set: { appModel.setTwitchEnabled($0) }
                )) {
                    EmptyView()
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(DesignTokens.Common.primary(colorScheme))
                .labelsHidden()

                statusIndicator
            }

            if appModel.twitchEnabled {
                channelControls

                if case .error(let msg) = appModel.twitchStatus {
                    Text(msg)
                        .font(.system(size: DesignTokens.Typography.Size.xs))
                        .foregroundStyle(DesignTokens.ColorToken.State.warning)
                }

                Text("Viewers: !theme, !scene, !shape, !randomize, !glitch, !abstract")
                    .font(.system(size: DesignTokens.Typography.Size.xs))
                    .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
            }
        }
        .padding(.top, DesignTokens.Spacing.sm)
    }

    private var channelControls: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            TextField("Channel name", text: Binding(
                get: { appModel.twitchChannelName },
                set: { appModel.setTwitchChannel($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(size: DesignTokens.Typography.Size.sm))
            .frame(maxWidth: 200)
            .onSubmit {
                if !appModel.twitchChannelName.isEmpty {
                    appModel.connectTwitch()
                }
            }

            connectButton
        }
    }

    @ViewBuilder
    private var connectButton: some View {
        if appModel.twitchStatus == .connected {
            Button(action: { appModel.disconnectTwitch() }) {
                Text("Disconnect")
                    .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.regular))
                    .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
            }
            .buttonStyle(.plain)
        } else if appModel.twitchStatus == .disconnected || appModel.twitchStatus != .connecting {
            Button(action: { appModel.connectTwitch() }) {
                Text("Connect")
                    .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(DesignTokens.Common.primary(colorScheme))
            }
            .buttonStyle(.plain)
            .disabled(appModel.twitchChannelName.isEmpty)
        }
    }

    private var statusIndicator: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusLabel)
                .font(.system(size: DesignTokens.Typography.Size.xs))
                .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
        }
    }

    private var statusColor: Color {
        switch appModel.twitchStatus {
        case .connected: return DesignTokens.ColorToken.State.success
        case .connecting: return DesignTokens.ColorToken.State.warning
        case .error: return DesignTokens.ColorToken.State.error
        case .disconnected: return DesignTokens.Common.Text.tertiary(colorScheme)
        }
    }

    private var statusLabel: String {
        switch appModel.twitchStatus {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .error: return "Error"
        case .disconnected: return "Off"
        }
    }
}
