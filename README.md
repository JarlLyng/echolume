# Echolume

[![Build and Test](https://github.com/JarlLyng/echolume/actions/workflows/build.yml/badge.svg)](https://github.com/JarlLyng/echolume/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue.svg)](https://www.apple.com/macos/)
[![Swift 5 mode · Xcode 16+](https://img.shields.io/badge/Swift-5%20mode%20%C2%B7%20Xcode%2016%2B-orange.svg)](https://swift.org)
[![Co-created with AI](https://madebyhuman.iamjarl.com/badges/co-created-white.svg)](https://madebyhuman.iamjarl.com)

A macOS app for **live, audio‑reactive 2D visuals** rendered with **Metal**. Echolume is meant as a **performance tool**: choose an **audio input device** (audio interface inputs, loopback inputs, mic, etc.), pick a visual theme/scene, tweak a few performance knobs, hit **Ready**, and perform.

> Design goals: **stable**, **low‑latency**, **minimal UI**, **beautiful results with few controls**, and a **clean architecture** that's deterministic to extend.

**Other repo docs:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) covers the layering, type contracts, milestones, and development conventions. `SEO_STRATEGY.md` (Danish) covers SEO for the GitHub Pages site in `docs/` only.

---

## Status

A quick reference of what's shipped vs planned. For the intended design, layering, and milestones, see [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

### Implemented now
- Metal renderer for 2D visuals (procedural shapes + a two‑pass decaying feedback/trail accumulation; trail length follows Abstraction, cleared by Panic Reset).
- Audio engine: input‑device enumeration, in‑app device switching, channel‑pair selection, safe fallback, live RMS/peak meter, FFT bands (low/mid/high).
- SetupView and LiveView (fullscreen output, minimal overlay, no‑signal banner, Panic Reset).
- 6 themes, **8 scenes** (radial, flow, grid, spiral, tunnel, kaleidoscope, plasma, spectrum ring), 5 shape styles, performance knobs, and Randomize.
- External display output selection.
- Twitch chat integration (anonymous read‑only IRC, viewer commands).
- Preset system: save/recall/delete named visual configurations (UI, `⌘1–9`, `!preset` chat command).
- MIDI controller support: MIDI Learn binds the 5 knobs to CC and notes to randomize/panic/next+previous theme.
- Beat detection: autocorrelation BPM + beat-phase tracking exposed to shaders (subtle tempo-synced pulse), with tap-tempo fallback.
- OSC input: opt-in UDP listener (default port 9000) mapping a `/echolume/…` namespace to knobs, theme/scene/shape, and triggers — for TouchDesigner/Resolume rigs.
- Menu bar extra: quick actions (Randomize, Panic Reset, Restart Audio), live status, and Open Echolume — reachable while running fullscreen on another display.
- Audio plugin (beta): bundled `EcholumeAudioTap` AUv3 — drop it on a DAW track and it forwards analysed bands + host BPM to Echolume over OSC (no BlackHole). See [Audio plugin (beta)](#audio-plugin-beta).
- Settings persistence in `UserDefaults`.
- Crash reporting via Apple's built‑in tooling (Xcode Organizer / App Store Connect) — no third‑party SDK. See [Crash reporting](#crash-reporting).

### Planned
- Video recording/export ([#6](https://github.com/JarlLyng/echolume/issues/6)).
- Twitch OAuth for authenticated features ([#4](https://github.com/JarlLyng/echolume/issues/4)).
- Danish localization ([#9](https://github.com/JarlLyng/echolume/issues/9)).

---

## Product vision

Echolume turns sound into light. **Constraints (App Store friendly):**
- Echolume captures **audio input** only (via CoreAudio/AVAudioEngine). It does **not** capture “system audio” directly.
- Requires **Microphone** permission (even for audio interfaces on macOS in practice).

---

## Themes

Themes are curated presets that define palette + motion style. V1 ships with 6 themes:

1. **Summer** – warm palette, soft gradients, slow drift.
2. **Winter** – cool palette, crystalline shapes, sharper transients.
3. **Dark Ambient** – low saturation, long trails, subtle noise.
4. **Techno Club** – high contrast, strobes on peaks, geometric repetition.
5. **Neon Lines** – line/scan aesthetic, mid/high reactive.
6. **Monochrome** – single hue + intensity modulation.

A theme defines:
- `palette` (3–5 colors)
- `baseMotion` (speed, rotation)
- `shapeStyle` (circles/lines/blobs)
- `trailStyle` (persistence)

**Randomize** should:
- keep within the current theme’s constraints
- change `seed`
- optionally nudge palette slightly

---

## Presets

Presets capture the full visual state — theme, shape style, scene, and all five performance knobs (seed is excluded; it's regenerated on Randomize). They let you switch between pre‑dialed looks instantly during a set.

- **Save** the current look from the Presets section in SetupView (names must be unique).
- **Recall** by clicking a preset, pressing `⌘1`–`⌘9` for the first nine, or via the `!preset <name>` Twitch chat command.
- **Delete** via a preset's context menu.
- Presets are stored as JSON in Application Support and persist across launches.

---

## Beat & tempo

Echolume estimates tempo from the low‑band onset envelope (autocorrelation over a multi‑second window, 80–180 BPM) and tracks a beat phase with a phase‑locked loop. `beatPhase` (0–1) and `bpm` are passed to the Metal shaders, which add a subtle brightness pulse on each beat (no‑op until a tempo lock is found).

- The **Tempo** area in Input & Output shows the detected BPM with a lock indicator.
- **Tap tempo:** tap the **Tap** button (or bind a MIDI note to *Tap Tempo* via MIDI Learn) to set the tempo manually; the Manual toggle holds it.
- Detection works on mic or BlackHole‑routed input.

---

## Audio plugin (beta)

`EcholumeAudioTap` is an AUv3 audio‑effect bundled inside Echolume.app — installing the app auto‑registers it (no separate installer). Drop it on a track in Ableton (Live 11.3+) or any AU host; it passes audio through and forwards the analysed bands + host BPM to Echolume over OSC (loopback). Enable OSC in Echolume (port 9000) and the visuals react to that track — no BlackHole/loopback routing.

> Note (beta): the plugin currently sends OSC from the render thread (best‑effort, non‑blocking). A v2 will move transport off the realtime thread.

---

## OSC control

Echolume can listen for **OSC over UDP** so it slots into TouchDesigner, Resolume, or any show-control rig. It's **opt-in**: enable it and set the port (default **9000**) in the OSC area of Input & Output. Enabling it requires the incoming-network sandbox entitlement (already configured).

Address namespace:

| Address | Arg | Effect |
|---------|-----|--------|
| `/echolume/knob/abstraction` (also `energybias`, `motion`, `noise`, `glitch`) | float 0–1 | Set that knob |
| `/echolume/theme` / `/echolume/scene` / `/echolume/shape` | int | Select by index |
| `/echolume/nexttheme` / `/echolume/prevtheme` | — | Cycle theme |
| `/echolume/randomize` / `/echolume/panic` / `/echolume/tempo/tap` | — | Trigger |
| `/echolume/preset` | int (slot) or string (name) | Recall preset |

Example: send `/echolume/knob/abstraction 0.8` to set abstraction to 80%.

---

## MIDI control

Echolume reads from any class‑compliant MIDI input via CoreMIDI (no driver or entitlement needed — it runs under the App Sandbox). Bindings are global and persist in `UserDefaults`.

- Open the **MIDI** area in Input & Output and toggle **MIDI Learn**.
- **Knobs:** click a knob to arm it, then move a CC on your controller — it binds and shows a `CC n` badge. Moving that CC then drives the knob.
- **Note triggers:** use the per‑action **Learn** buttons to bind notes to Randomize, Panic Reset, Next Theme, and Previous Theme.
- Connect a controller, or test without hardware via the **IAC Driver** in *Audio MIDI Setup*.

---

## UX / Interaction

### SetupView
- Persist user setup in `UserDefaults`: input device, channel pair, theme, shape style, scene, abstraction, energy bias, motion, noise, glitch, output display, and Twitch settings. Seed is intentionally not persisted — Randomize generates a new seed each launch.
- Show a clear “Signal detected” indicator.
- Keep controls minimal; avoid adding settings that don’t directly improve live performance.
- Expose a small secondary action for **Panic Reset** (visuals only).
- No manual Refresh button — the app should update device lists automatically.
- No "Show advanced devices" toggle in V1 — keep the device list focused and friendly.
- Layout: use a Mac-optimized two-column layout (Audio on the left, Visuals on the right) with knobs arranged horizontally to reduce vertical scrolling.

### LiveView
- Fullscreen (toggle) with minimal chrome.
- ESC exits fullscreen; `⌘.` or Back button exits Live.
- Keyboard-first: Space = Randomize, Enter = Exit/Back, R = Panic Reset, ⌘R = Restart audio, 1–6 = themes, ⌘1–⌘9 = recall presets.

---

## Twitch Chat integration

Echolume can connect to a Twitch channel's chat (read-only, anonymous) and react to viewer commands in real time. This turns streams into interactive visual experiences.

### How it works

`TwitchChatManager` connects to Twitch IRC via WebSocket (`wss://irc-ws.chat.twitch.tv:443`) as an anonymous viewer (`justinfan*`). No OAuth or login required — it only reads public chat messages.

### Chat commands

| Command | Effect |
|---------|--------|
| `!theme <name>` | Switch theme (e.g. `!theme summer`, `!theme techno club`) |
| `!scene <name>` | Switch scene type (`radial`, `flow`, `grid`) |
| `!shape <name>` | Switch shape style (`blobs`, `circles`, `lines`, `grid`, `particles`) |
| `!randomize` | Random theme + seed |
| `!glitch` | Toggle glitch intensity |
| `!abstract <0–100>` | Set abstraction level |
| `!preset <name>` | Recall a saved preset by name |

### Rate limiting

Commands are rate-limited to 1 per second to prevent chat spam from thrashing visuals.

### Reconnection

On disconnect, the manager retries up to 3 times with a 5-second delay between attempts.

### Setup (user)

1. In SetupView, enable **Twitch Chat** and enter the channel name.
2. Echolume connects automatically. Status indicator shows connection state (green/yellow/red/gray).
3. Settings persist in UserDefaults.

---

## Permissions

Add this to `Info.plist`:

- `NSMicrophoneUsageDescription`: "Echolume needs access to an audio input source to drive real‑time visuals."

If using external display APIs later, ensure no unnecessary entitlements.

---


## Technical requirements

- macOS 14+ (Sonoma)
- Xcode 16+ (project builds in **Swift 5 language mode** — `SWIFT_VERSION = 5.0` — using the Swift 6 toolchain that ships with Xcode 16)
- SwiftUI for UI
- Metal / MetalKit for rendering
- AVFoundation (AVAudioEngine) + Accelerate for FFT

---

## Design system (required)

Echolume must use the **IAMJARL design system** from:
- https://github.com/JarlLyng/iamjarl-design

**Rules:**
- Do not create ad-hoc colors, spacings, corner radii, or typography.
- Use design tokens/components from the design system for **all UI** in the main app (SetupView, LiveView overlays, pickers, buttons, sliders, etc.).
- Keep UI minimal, but consistent.

> **Exception — AUv3 plugin UI.** The `EcholumeAudioTap` app-extension target does **not** link the `IAMJARLDesignTokens` package (keeps the extension lean; the AU host controls view sizing). Its small SwiftUI view uses plain SwiftUI with consistent spacing instead of tokens.
>
> **Exception — `LiveView` overlay.** Overlay chrome is drawn on top of arbitrary Metal output (which can be bright or dark), so it uses fixed dark scrims + light text for legibility on any visuals rather than `colorScheme` tokens (which track the app background, not the canvas).

### Integration

The design system is integrated as a **Swift Package Manager** dependency (already added to the Xcode project):
- **Package:** `IAMJARLDesignTokens` from `https://github.com/JarlLyng/iamjarl-design`
- **Version:** `upToNextMajorVersion` from 1.0.0
- **Update:** *File → Packages → Update to Latest Package Versions* in Xcode

There is **no local copy** of `DesignTokens.swift` — tokens come directly from the SPM package.

### Usage conventions

- Add `import IAMJARLDesignTokens` in any SwiftUI view that uses design tokens.
- Use token-based:
  - Colors: `DesignTokens.Common.primary(colorScheme)`, `DesignTokens.ColorToken.State.success`, etc.
  - Typography: `DesignTokens.Typography.Size.sm`, `DesignTokens.Typography.Weight.semibold`
  - Spacing: `DesignTokens.Spacing.md`, `DesignTokens.Spacing.xl`
  - Corner radius: `DesignTokens.Radius.md`
- The marketing site (`docs/styles.css`) mirrors the dark-mode tokens as CSS custom properties.

---

## Marketing site (GitHub Pages)

A one-page marketing site lives in **`docs/`** and can be hosted on GitHub Pages:

1. **GitHub** → repo **Settings** → **Pages**.
2. Under **Build and deployment**, **Source**: *Deploy from a branch*.
3. **Branch**: `main`, **Folder**: `/docs`. Save.

The site will be available at `https://<username>.github.io/echolume/` (or your custom domain if configured).

- **`docs/index.html`** — landing page (hero, features, download).
- **`docs/how-it-works.html`** — setup guide (mic, audio interface, BlackHole, troubleshooting).
- **`docs/obs-guide.html`** — OBS Studio integration guide (BlackHole routing, monitor output, streaming tips).
- **`docs/twitch-guide.html`** — Twitch chat integration guide (setup, commands, stream workflow).
- **`docs/privacy.html`** — privacy policy.
- **`docs/support.html`** — FAQ and contact (GitHub Issues).
- **`docs/styles.css`** — styles (Echolume accent colors, dark theme).
- **`docs/.nojekyll`** — disables Jekyll so static files are served as-is.

When the app is on the Mac App Store, replace the download CTA in `docs/index.html` with the App Store link.

- **Privacy policy:** `docs/privacy.html` → e.g. `https://JarlLyng.github.io/echolume/privacy.html` (use this URL in App Store Connect).
- **Support:** `docs/support.html` — FAQ and contact. Link from the App Store listing if you want.

---

## Crash reporting

Echolume uses **Apple's built-in crash reporting** — no third-party SDK or DSN. For TestFlight and App Store builds, crash reports from users who opt into sharing analytics flow automatically into **Xcode → Window → Organizer → Crashes** and App Store Connect, symbolicated from the dSYMs uploaded at archive time.

- Nothing to configure: archive and upload as usual; dSYMs are produced by the Release config (`DEBUG_INFORMATION_FORMAT = dwarf-with-dsym`).
- Reports are aggregated and post-release only (not real-time, and not collected during local development).
- If richer on-device diagnostics are needed later (hangs, launch/CPU/disk metrics), [MetricKit](https://developer.apple.com/documentation/metrickit) (`MXMetricManager`) can be added with no third-party dependency.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for notable changes.

## License

MIT — see [LICENSE](LICENSE) for full text.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, code style, and how to submit pull requests.

## Security

Found a vulnerability? Please see [SECURITY.md](SECURITY.md) for the reporting process.
