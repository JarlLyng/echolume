//
//  LiveView.swift
//  echolume
//

import AppKit
import IAMJARLDesignTokens
import SwiftUI

struct LiveView: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme

    // Overlay chrome sits on top of arbitrary Metal output (which can be bright
    // or dark), so it uses fixed scrims + light text for legibility on ANY
    // visuals — colorScheme tokens track the app background, not the canvas.
    private let overlayScrim = Color.black.opacity(0.55)
    private let overlayText = Color.white

    /// Live is a performance surface: the Back/Panic chrome fades out after a
    /// few idle seconds (like fullscreen video players) and returns on any
    /// mouse movement. Keyboard shortcuts keep working while hidden because
    /// the buttons stay in the hierarchy (opacity 0, hit-testing off).
    private static let chromeIdleSeconds: Double = 3
    @State private var chromeVisible = true
    @State private var pointerOverChrome = false
    @State private var chromeHideTask: Task<Void, Never>?
    @State private var lastChromePoke = Date.distantPast

    var body: some View {
        ZStack {
            MetalView(
                visualParamsProvider: appModel.visualParamsProvider,
                onError: { [weak appModel] msg in appModel?.setRendererError(msg) }
            )
                .ignoresSafeArea()

            if let err = appModel.rendererError {
                rendererErrorOverlay(err)
            }

            // Overlay: Back + Panic hint + meter. Fades out when idle; the
            // buttons are outlined scrims (not filled) so they read as chrome,
            // not as part of the show.
            VStack {
                HStack {
                    Button(action: { appModel.exitLive() }) {
                        Text("Back")
                            .font(.system(size: DesignTokens.Typography.Size.base, weight: DesignTokens.Typography.Weight.semibold))
                            .foregroundStyle(overlayText)
                            .padding(.horizontal, DesignTokens.Spacing.xl)
                            .padding(.vertical, DesignTokens.Spacing.md)
                            .frame(minHeight: 44)
                            .background(overlayScrim)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                                    .strokeBorder(overlayText.opacity(0.35), lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [])
                    .accessibilityLabel("Exit Live")
                    // Panic is the most important live control — it keeps the
                    // warning tint (as outline + text) so it stays glanceable.
                    Button(action: { appModel.panicReset() }) {
                        Text("Panic (R)")
                            .font(.system(size: DesignTokens.Typography.Size.base, weight: DesignTokens.Typography.Weight.semibold))
                            .foregroundStyle(DesignTokens.ColorToken.State.warning)
                            .padding(.horizontal, DesignTokens.Spacing.xl)
                            .padding(.vertical, DesignTokens.Spacing.md)
                            .frame(minHeight: 44)
                            .background(overlayScrim)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                                    .strokeBorder(DesignTokens.ColorToken.State.warning.opacity(0.6), lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("r", modifiers: [])
                    .accessibilityLabel("Panic reset visuals")
                    Spacer()
                    if appModel.hasMicPermission {
                        LevelMeterView(rms: appModel.rms, peak: appModel.peak, compact: true)
                            .frame(width: 80, height: 14)
                    }
                }
                .padding(DesignTokens.Spacing.lg)
                .onHover { inside in
                    pointerOverChrome = inside
                    if inside { showChrome() } else { scheduleChromeHide() }
                }
                Spacer()
            }
            .opacity(chromeVisible ? 1 : 0)
            .allowsHitTesting(chromeVisible)

            if !appModel.hasSignal {
                // Centered at the top so it never overlaps the Back button (left)
                // or the level meter (right).
                VStack {
                    VStack(spacing: DesignTokens.Spacing.xs) {
                        Text("NO SIGNAL")
                            .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.bold))
                            .foregroundStyle(DesignTokens.ColorToken.State.warning)
                        Text("Check input device / routing")
                            .font(.system(size: DesignTokens.Typography.Size.xs))
                            .foregroundStyle(overlayText)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(overlayScrim)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 64)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("No audio signal. Check input device or routing.")
            }

            if !appModel.debugEngineRunning {
                VStack {
                    Spacer()
                    Text("Press ⌘R to restart audio")
                        .font(.system(size: DesignTokens.Typography.Size.sm))
                        .foregroundStyle(overlayText)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .background(overlayScrim)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
                        .padding(.bottom, 60)
                }
            }

            #if DEBUG
            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Motion: \(String(format: "%.2f", appModel.motion))  Noise: \(String(format: "%.2f", appModel.noise))  Glitch: \(String(format: "%.2f", appModel.glitch))")
                    Text("Impact: \(String(format: "%.2f", appModel.impact))  Peak: \(String(format: "%.2f", appModel.peak))")
                }
                .font(.system(size: DesignTokens.Typography.Size.xs, weight: DesignTokens.Typography.Weight.semibold))
                .foregroundStyle(overlayText)
                .padding(DesignTokens.Spacing.sm)
                .background(overlayScrim)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
                .padding(.bottom, 16)
            }
            #endif
        }
        .background(DesignTokens.Common.Background.app(colorScheme))
        .background(MouseActivityMonitor(onActivity: showChrome))
        .onContinuousHover { phase in
            if case .active = phase { showChrome() }
        }
        .onAppear { scheduleChromeHide() }
        .onDisappear { chromeHideTask?.cancel() }
        .onExitCommand { appModel.exitLive() }
        .onKeyPress(.escape) {
            appModel.exitLive()
            return .handled
        }
    }

    /// Reveal the chrome and restart the idle countdown. Throttled: mouse-moved
    /// events arrive at pointer rate, and each poke would otherwise cancel and
    /// recreate the hide task.
    private func showChrome() {
        if !chromeVisible {
            withAnimation(.easeOut(duration: 0.15)) { chromeVisible = true }
        }
        let now = Date()
        guard now.timeIntervalSince(lastChromePoke) > 0.25 else { return }
        lastChromePoke = now
        scheduleChromeHide()
    }

    /// Hide the chrome after the idle interval — unless the pointer is resting
    /// on it (nothing should vanish under the cursor mid-click).
    private func scheduleChromeHide() {
        chromeHideTask?.cancel()
        chromeHideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.chromeIdleSeconds))
            guard !Task.isCancelled, !pointerOverChrome else { return }
            withAnimation(.easeOut(duration: 0.4)) { chromeVisible = false }
            // A performance surface shouldn't show a parked cursor either.
            NSCursor.setHiddenUntilMouseMoves(true)
        }
    }

    private func rendererErrorOverlay(_ message: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(DesignTokens.ColorToken.State.warning)
                .accessibilityHidden(true)
            Text("Renderer error")
                .font(.system(size: DesignTokens.Typography.Size.lg, weight: DesignTokens.Typography.Weight.bold))
                .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))
            Text(message)
                .font(.system(size: DesignTokens.Typography.Size.sm))
                .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.xl)
            Button(action: {
                appModel.setRendererError(nil)
                appModel.exitLive()
            }) {
                Text("Back to Setup")
                    .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(DesignTokens.Common.primary(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.Spacing.xxl)
        .background(DesignTokens.Common.Background.card(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
        .shadow(radius: 16)
    }
}

/// AppKit bridge for chrome auto-hide: SwiftUI's hover tracking alone can be
/// unreliable over a fullscreen Metal surface, so this also listens for
/// app-level mouse-moved and click events. Any of them counts as activity —
/// including the first click while the chrome is hidden, so the controls are
/// never unreachable.
private struct MouseActivityMonitor: NSViewRepresentable {
    let onActivity: () -> Void

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.onActivity = onActivity
        return view
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.onActivity = onActivity
    }

    final class MonitorView: NSView {
        var onActivity: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else {
                removeMonitor()
                return
            }
            // Without this, no mouse-moved events are generated at all.
            window.acceptsMouseMovedEvents = true
            if monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown]) { [weak self] event in
                    self?.onActivity?()
                    return event
                }
            }
        }

        private func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            removeMonitor()
        }
    }
}

#Preview {
    LiveView(appModel: AppModel())
        .frame(width: 800, height: 600)
}
