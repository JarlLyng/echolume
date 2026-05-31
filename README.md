# Echolume

[![Build and Test](https://github.com/JarlLyng/echolume/actions/workflows/build.yml/badge.svg)](https://github.com/JarlLyng/echolume/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue.svg)](https://www.apple.com/macos/)
[![Swift 5 mode · Xcode 16+](https://img.shields.io/badge/Swift-5%20mode%20%C2%B7%20Xcode%2016%2B-orange.svg)](https://swift.org)
[![Co-created with AI](https://madebyhuman.iamjarl.com/badges/co-created-white.svg)](https://madebyhuman.iamjarl.com)

A macOS app for **live, audio‑reactive 2D visuals** rendered with **Metal**. Echolume is meant as a **performance tool**: choose an **audio input device** (audio interface inputs, loopback inputs, mic, etc.), pick a visual theme/scene, tweak a few performance knobs, hit **Ready**, and perform.

> Design goals: **stable**, **low‑latency**, **minimal UI**, **beautiful results with few controls**, and a **clean architecture** that Cursor can extend deterministically.

**Other repo docs:** `SEO_STRATEGY.md` (Danish) covers SEO for the GitHub Pages site in `docs/` only — not app architecture.

---

## Status

This README mixes shipped features with target architecture. The split below is the quick reference; the **Architecture** and **Milestones** sections further down describe the intended design (which Cursor follows when extending the app).

### Implemented now
- Metal renderer for 2D visuals (procedural shapes + a two‑pass decaying feedback/trail accumulation; trail length follows Abstraction, cleared by Panic Reset).
- Audio engine: input‑device enumeration, in‑app device switching, channel‑pair selection, safe fallback, live RMS/peak meter, FFT bands (low/mid/high).
- SetupView and LiveView (fullscreen output, minimal overlay, no‑signal banner, Panic Reset).
- 6 themes, **7 scenes** (radial, flow, grid, spiral, tunnel, kaleidoscope, plasma), 5 shape styles, performance knobs, and Randomize.
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

## V1 scope (ship‑able)

### Must‑have
- **Metal renderer** for 2D visuals (scene pass + ping‑pong feedback/trail pass).
- **Audio engine** that:
  - enumerates available **audio input devices** (input‑only)
  - allows selecting an **audio input device** directly in-app (without changing macOS system default)
  - allows selecting a **stereo channel pair** when the chosen device has multiple channels (e.g. 1–2, 3–4)
  - falls back safely to current/default input if a selected device cannot be activated
  - provides a live **input meter** (RMS + peak)
  - runs a lightweight **FFT** (at least 3 bands: low/mid/high)
- **Setup screen** (SwiftUI):
  - Audio input device picker (in-app switching)
  - Channel pair picker (when available)
  - Signal indicator + tiny level meter
  - Theme picker
  - Scene picker
  - Shape style picker
  - Performance knobs: Abstraction, Energy Bias, Motion, Noise, Glitch
  - Randomize button
  - Output Display picker (Auto/Main or external display)
  - Twitch Chat toggle + channel name (anonymous IRC, viewer commands)
  - Ready button
- **Live screen**:
  - Fullscreen Metal output
  - Minimal overlay (ESC/Back, tiny audio meter, optional NO SIGNAL banner)

### Nice‑to‑have (after V1)
- Presets (save/load theme + abstraction + seed).
- Additional analysis: onset detection, beat estimation.
- Multiple scenes.
- Twitch EventSub (react to follows, subs, bits with visual triggers).

---

## Architecture (Cursor should follow this)

Keep the system in **four layers** with clear boundaries:

1) **Audio** (input + analysis + envelopes + transient detection)
2) **Mapping** (turn analysis into normalized params)
3) **Scene** (defines geometry + motion behavior)
4) **Render** (Metal draws frames using params)

SwiftUI should be **thin** and mostly wire views to an `AppModel`.

### Modules / folders

Current layout in the Xcode project (keep new files in these groups):

```
echolume/
  App/
    EcholumeApp.swift
    AppModel.swift
    TwitchChatManager.swift
    ExternalDisplaySupport.swift
  UI/
    SetupView.swift
    LiveView.swift
    Components/
      LevelMeterView.swift
      KnobView.swift
  Audio/
    AudioManager.swift
    AudioDevice.swift
    AudioAnalyzer.swift
    FFT.swift
  Visuals/
    VisualParams.swift
    VisualParamsProvider.swift
    Theme.swift
    ThemeLibrary.swift
    ParamMapping.swift
    SceneType.swift
    ShapeStyle.swift
  Renderer/
    MetalView.swift
    Renderer.swift
    Shaders.metal
  Utilities/
    SmoothValue.swift
    Log.swift
```

### Key types (contracts)

#### `AppModel` (ObservableObject)
Responsibilities:
- App state machine: `.setup` / `.live`
- User selections: selected device, channel pair, theme, abstraction, seed
- Lifecycle: start/stop audio + start/stop renderer

Public API sketch:
- `func start()` (requests permission + starts audio)
- `func enterLive()` (locks UI, switches to LiveView)
- `func exitLive()`

#### `AudioManager`
Responsibilities:
- Enumerate input devices.
- Configure audio session/engine.
- Provide audio buffers to analyzer.

Implementation notes:
- Prefer **CoreAudio / AVAudioEngine**.
- Use a tap (or AudioUnit input callback) to pull PCM frames.
- Keep latency low (buffer size target 128–256 frames where stable).
- Update device enumeration automatically (e.g., listen for device change notifications) rather than requiring a manual refresh UI.

#### `AudioAnalyzer`
Responsibilities:
- Compute:
  - `rms` (0…1)
  - `peak` (0…1)
  - `bands`: `[low, mid, high]` (0…1)
- Provide smoothed values.

V1 approach:
- Downmix stereo to mono for analysis (optional keep stereo later).
- FFT size 1024 or 2048, hop 256–512.
- Bands split example:
  - low: 20–200 Hz
  - mid: 200–2000 Hz
  - high: 2000–12000 Hz

#### `VisualParams`
A normalized struct passed into the renderer each frame:

- `time`: Double
- `level`: Float (rms)
- `peak`: Float
- `low/mid/high`: Float
- `abstraction`: Float (0…1)
- `palette`: 3–5 colors (as float4)
- `seed`: UInt32

#### `SceneType`
Defines fundamentally different visual behaviors.

enum SceneType {
    case radial
    case flow
    case grid
    case spiral
    case tunnel
    case kaleidoscope
    case plasma
}

Themes define color and mood.
Scenes define geometry, motion logic, and audio interpretation.

Scenes must not simply recolor the same shader logic — they must implement different spatial structures and different mappings of audio (low/mid/high, impact, impulse).

#### `ParamMapping`
Turns analyzer outputs into stable, musical motion:
- Attack/release smoothing
- Nonlinear curves (e.g. `pow`, `smoothstep`)
- “Abstraction” controls:
  - shape count
  - noise strength
  - warp amount
  - trail persistence
  - hue drift

#### `Renderer` (Metal)
Responsibilities:
- Maintain pipeline state.
- Draw a fullscreen quad.
- Ping‑pong feedback buffer for decaying trails.

Rendering strategy (implemented):
- **Pass A**: scene fragment blended over a decayed copy of the previous frame (`max(scene, prev × trailPersistence)`) into an offscreen `rgba16Float` accumulation texture (ping‑pong).
- **Pass B**: present the accumulation texture to the drawable. Falls back to a single direct pass if textures can't be created; trails clear on Panic Reset.

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

## Milestones

### Milestone 1 — Skeleton runs
- SwiftUI SetupView + LiveView navigation
- MetalView renders a test shader (time-based animation)

### Milestone 2 — Audio input works (system default baseline)
- Permission prompt
- AVAudioEngine input tap
- Live meter (rms/peak)
- Stable capture from macOS default input

### Milestone 2.5 — In‑app device switching (Pro)
- Enumerate input devices (CoreAudio, input‑only)
- Audio Source dropdown (real device switching)
- Deterministic engine restart model (teardown → new engine → set device → start)
- Channel pair picker based on selected device
- Safe fallback if device activation fails
- No modification of macOS system default input

### Milestone 3 — Musical Audio Engine

- FFT bands
- Envelope smoothing (attack/release per band)
- Impact detection (low transient boost)
- Peak impulse system
- ParamMapping based on smoothed values

### Milestone 3.5 — Scene System

- Introduce SceneType (radial, flow, grid)
- Scene picker in SetupView
- Separate shader logic per scene
- Unique audio interpretation per scene
- Maintain performance stability

### Milestone 4 — Themes + Randomize
- Theme library
- Randomization seed
- Persist last used settings

### Milestone 5 — Live readiness
- Fullscreen stability
- External display support (select output display; Live on external, Setup on main)
- Performance tuning (FPS stable, no stutters)
- Keyboard shortcuts for live use (Space/Enter/R/⌘R + 1–6 themes)
- No-signal detection + minimal banner in LiveView
- Panic Reset (resets visuals without restarting audio)
- Restart audio action + basic error banner

---

## Development notes for Cursor

When implementing, follow these rules:

1. **Small, testable steps**. Prefer compiling after each file.
2. Keep SwiftUI views dumb; most logic goes into `AppModel` and subsystems.
3. Approved third-party deps: **IAMJARLDesignTokens** (design system). Avoid adding others without good reason.
4. Prefer deterministic code (no hidden magic).
5. Add lightweight logging around audio start/stop and input format (avoid logging inside realtime callbacks).
6. Device switching must use a deterministic restart model (dispose engine → create new engine → set device → install tap → start). Avoid KVC hacks or private API access.
7. Scenes must represent genuinely different spatial and motion logic — avoid copying the same shader code with minor variations.

### Console noise

During development you may see CoreAudio/HAL console messages such as `proxy failed (nope)`, `Unable to obtain a task name port right`, occasional `IOWorkLoop: skipping cycle due to overload` during start/stop, or `-10877` spam.

Treat these as **non-blocking** if:
- audio capture works,
- device switching works,
- visuals remain stable.

Avoid adding logging inside realtime callbacks.

### Pre-review checklist

Before external review / TestFlight:
- Remove or throttle any `-10877` spam logging.
- Ensure no debug-only UI is shown in Release builds.
- Confirm microphone permission copy and behavior.
- Verify device switching + external display behavior is stable.
- Avoid heavy work/logging in realtime callbacks.
- Keep UI minimal: only performance-critical controls.

---

## Out of scope for V1

- Capturing system audio output without routing
- MIDI input
- Complex beat grid detection
- Video recording/export
- Twitch OAuth / authenticated connections (anonymous read-only is sufficient for V1)

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
