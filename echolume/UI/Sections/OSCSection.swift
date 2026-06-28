//
//  OSCSection.swift
//  echolume
//
//  OSC input settings: enable toggle, UDP port, and status. Lives in Input &
//  Output as another input source. Addresses use the fixed /echolume/...
//  namespace (documented in the README).
//

import IAMJARLDesignTokens
import SwiftUI

struct OSCSection: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var server: OSCServer
    @Environment(\.colorScheme) private var colorScheme
    @State private var portText: String = ""

    init(appModel: AppModel) {
        self.appModel = appModel
        self.server = appModel.oscServer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text("OSC")
                    .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(statusText)
                    .font(.system(size: DesignTokens.Typography.Size.xs))
                    .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                Spacer()
                Toggle("Enable", isOn: Binding(
                    get: { appModel.oscEnabled },
                    set: { appModel.setOSCEnabled($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(DesignTokens.Common.primary(colorScheme))
            }

            HStack(spacing: DesignTokens.Spacing.sm) {
                Text("Port")
                    .font(.system(size: DesignTokens.Typography.Size.xs))
                    .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
                TextField("9000", text: $portText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .onSubmit { commitPort() }
                    .accessibilityLabel("OSC listener port")
            }

            Text("Send to /echolume/… (knob/abstraction, theme, randomize, preset…)")
                .font(.system(size: DesignTokens.Typography.Size.xs))
                .foregroundStyle(DesignTokens.Common.Text.tertiary(colorScheme))
        }
        .padding(.top, DesignTokens.Spacing.xs)
        .onAppear { portText = String(appModel.oscPort) }
    }

    private func commitPort() {
        if let p = UInt16(portText.trimmingCharacters(in: .whitespaces)), p > 0 {
            appModel.setOSCPort(p)
        } else {
            portText = String(appModel.oscPort)   // revert invalid input
        }
    }

    private var statusText: String {
        switch server.status {
        case .off: return "Off"
        case .listening(let port): return "Listening :\(port)"
        case .failed(let msg): return "Error: \(msg)"
        }
    }

    private var statusColor: Color {
        switch server.status {
        case .off: return DesignTokens.Common.Text.tertiary(colorScheme)
        case .listening: return DesignTokens.ColorToken.State.success
        case .failed: return DesignTokens.ColorToken.State.error
        }
    }
}
