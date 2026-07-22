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
    /// The brand lime, deliberately NOT scheme-aware: the overlay always sits
    /// on dark visuals, so it always uses the dark-mode accent.
    private let overlayAccent = DesignTokens.ColorToken.Dark.primary

    /// Live is a performance surface: the Back/Panic chrome fades out after a
    /// few idle seconds (like fullscreen video players) and returns on any
    /// mouse movement. Keyboard shortcuts keep working while hidden because
    /// the buttons stay in the hierarchy (opacity 0, hit-testing off).
    private static let chromeIdleSeconds: Double = 3
    @State private var chromeVisible = true
    @State private var pointerOverChrome = false
    @State private var chromeHideTask: Task<Void, Never>?
    @State private var lastChromePoke = Date.distantPast
    @State private var recordingPulse = false

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

            // Overlay chrome: everything that isn't the show fades out
            // together when idle and shares one design language — dark scrim,
            // 1pt lime outline, white text.
            Group {
                VStack {
                    HStack {
                        Button(action: { appModel.exitLive() }) {
                            Text("Back")
                                .font(.system(size: DesignTokens.Typography.Size.base, weight: DesignTokens.Typography.Weight.semibold))
                                .foregroundStyle(overlayText)
                                .padding(.horizontal, DesignTokens.Spacing.xl)
                                .padding(.vertical, DesignTokens.Spacing.md)
                                .frame(minHeight: 44)
                                .modifier(LiveChromeSurface(accent: overlayAccent, scrim: overlayScrim))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.return, modifiers: [])
                        .accessibilityLabel("Exit Live")
                        Button(action: { appModel.panicReset() }) {
                            Text("Panic (R)")
                                .font(.system(size: DesignTokens.Typography.Size.base, weight: DesignTokens.Typography.Weight.semibold))
                                .foregroundStyle(overlayText)
                                .padding(.horizontal, DesignTokens.Spacing.xl)
                                .padding(.vertical, DesignTokens.Spacing.md)
                                .frame(minHeight: 44)
                                .modifier(LiveChromeSurface(accent: overlayAccent, scrim: overlayScrim))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut("r", modifiers: [])
                        .accessibilityLabel("Panic reset visuals")
                        Button(action: { appModel.toggleRecording() }) {
                            HStack(spacing: DesignTokens.Spacing.xs) {
                                Circle()
                                    .fill(appModel.isRecording ? Color.red : overlayText.opacity(0.5))
                                    .frame(width: 8, height: 8)
                                Text(appModel.isRecording ? "Stop (V)" : "Record (V)")
                                    .font(.system(size: DesignTokens.Typography.Size.base, weight: DesignTokens.Typography.Weight.semibold))
                                    .foregroundStyle(overlayText)
                            }
                            .padding(.horizontal, DesignTokens.Spacing.xl)
                            .padding(.vertical, DesignTokens.Spacing.md)
                            .frame(minHeight: 44)
                            .modifier(LiveChromeSurface(accent: overlayAccent, scrim: overlayScrim))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut("v", modifiers: [])
                        .accessibilityLabel(appModel.isRecording ? "Stop recording" : "Record visuals to a video file")
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

                if !appModel.hasSignal {
                    // Centered at the top so it never overlaps the Back button
                    // (left) or the level meter (right).
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
                        .modifier(LiveChromeSurface(accent: overlayAccent, scrim: overlayScrim))
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
                            .modifier(LiveChromeSurface(accent: overlayAccent, scrim: overlayScrim, cornerRadius: DesignTokens.Radius.sm))
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
                    .modifier(LiveChromeSurface(accent: overlayAccent, scrim: overlayScrim, cornerRadius: DesignTokens.Radius.sm))
                    .padding(.bottom, 16)
                }
                #endif
            }
            .opacity(chromeVisible ? 1 : 0)
            .allowsHitTesting(chromeVisible)

            // Recording indicator: deliberately OUTSIDE the auto-hiding chrome.
            // A performer must always be able to see that capture is running.
            if appModel.isRecording {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .opacity(recordingPulse ? 1 : 0.35)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: recordingPulse)
                            .onAppear { recordingPulse = true }
                            .onDisappear { recordingPulse = false }
                            .accessibilityLabel("Recording")
                    }
                    .padding(DesignTokens.Spacing.lg)
                    Spacer()
                }
            }

            // Post-recording note ("Saved to Movies"). Also outside the chrome
            // so it is seen even when the controls are hidden; auto-clears.
            if let note = appModel.recordingNote {
                VStack {
                    Spacer()
                    Text(note)
                        .font(.system(size: DesignTokens.Typography.Size.sm, weight: DesignTokens.Typography.Weight.semibold))
                        .foregroundStyle(overlayText)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .modifier(LiveChromeSurface(accent: overlayAccent, scrim: overlayScrim, cornerRadius: DesignTokens.Radius.sm))
                        .padding(.bottom, 24)
                }
                .transition(.opacity)
            }
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

/// The one design language for everything floating over the visuals: a dark
/// translucent scrim with a thin brand-lime outline.
private struct LiveChromeSurface: ViewModifier {
    let accent: Color
    let scrim: Color
    var cornerRadius: CGFloat = DesignTokens.Radius.md

    func body(content: Content) -> some View {
        content
            .background(scrim)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(accent.opacity(0.6), lineWidth: 1)
            )
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
