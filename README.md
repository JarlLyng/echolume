# Echolume

A macOS app for **live, audio‑reactive 2D visuals** rendered with **Metal**. Echolume is meant as a **performance tool**: choose an **audio input device** (audio interface inputs, loopback inputs, mic, etc.), pick a visual theme/scene, tweak a few performance knobs, hit **Ready**, and perform.

> Design goals: **stable**, **low‑latency**, **minimal UI**, **beautiful results with few controls**, and a **clean architecture** that Cursor can extend deterministically.

---

## Product vision

Echolume turns sound into light.

**User flow (V1):**
1. Open the app.
2. Choose **Audio Input Device** and channel pair directly inside Echolume.
3. Choose a **Theme** (or press **Randomize**).
4. Set **Abstraction** (single slider controlling multiple internal parameters).
5. Press **Ready** → visuals go fullscreen (optionally on a selected external display) and react to audio.

**Important constraints (App Store friendly):**
- Echolume captures **audio input** only (via CoreAudio/AVAudioEngine). It does **not** capture “system audio” directly.
- Requires **Microphone** permission (even for audio interfaces on macOS in practice).

---

## V1 scope (ship‑able)

### Must‑have
- **Metal renderer** for 2D visuals (single fullscreen pass + optional trail/feedback pass).
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
  - Ready button
- **Live screen**:
  - Fullscreen Metal output
  - Minimal overlay (ESC/Back, tiny audio meter, optional NO SIGNAL banner)

### Nice‑to‑have (after V1)
- Presets (save/load theme + abstraction + seed).
- Additional analysis: onset detection, beat estimation.
- Multiple scenes.

---

## Architecture (Cursor should follow this)

Keep the system in **four layers** with clear boundaries:

1) **Audio** (input + analysis + envelopes + transient detection)
2) **Mapping** (turn analysis into normalized params)
3) **Scene** (defines geometry + motion behavior)
4) **Render** (Metal draws frames using params)

SwiftUI should be **thin** and mostly wire views to an `AppModel`.

### Modules / folders

Create these groups/folders in the Xcode project:

```
Echolume/
  App/
    EcholumeApp.swift
    AppModel.swift
  UI/
    SetupView.swift
    LiveView.swift
    Components/
      LevelMeterView.swift
      ThemePicker.swift
  Audio/
    AudioManager.swift
    AudioDevice.swift
    AudioAnalyzer.swift
    FFT.swift
  Visuals/
    VisualParams.swift
    Theme.swift
    ThemeLibrary.swift
    ParamMapping.swift
    SceneType.swift
  Renderer/
    MetalView.swift
    Renderer.swift
    Shaders.metal
  Utilities/
    RingBuffer.swift
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
- Optional feedback buffer for trails.

V1 rendering strategy:
- **Pass A**: draw procedural shapes in fragment shader using params.
- **Pass B** (optional): feedback/trails by mixing previous frame texture.

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

## UX / Interaction

### SetupView
- Persist last used **input device/channel pair/theme/abstraction/seed** in `UserDefaults`.
- Show a clear “Signal detected” indicator.
- Keep controls minimal; avoid adding settings that don’t directly improve live performance.
- Expose a small secondary action for **Panic Reset** (visuals only).
- No manual Refresh button — the app should update device lists automatically.
- No "Show advanced devices" toggle in V1 — keep the device list focused and friendly.
- Layout: use a Mac-optimized two-column layout (Audio on the left, Visuals on the right) with knobs arranged horizontally to reduce vertical scrolling.

### LiveView
- Fullscreen (toggle) with minimal chrome.
- ESC exits fullscreen; `⌘.` or Back button exits Live.
- Keyboard-first: Space = Randomize, Enter = Exit/Back, R = Panic Reset, ⌘R = Restart audio.

---

## Permissions

Add this to `Info.plist`:

- `NSMicrophoneUsageDescription`: "Echolume needs access to an audio input source to drive real‑time visuals."

If using external display APIs later, ensure no unnecessary entitlements.

---


## Technical requirements

- macOS 13+ (can be adjusted, but pick a stable baseline)
- SwiftUI for UI
- Metal / MetalKit for rendering
- AVFoundation (AVAudioEngine) + Accelerate for FFT

---

## Design system (required)

Echolume must use the **IAMJARL design system** from:
- https://github.com/JarlLyng/iamjarl-design

**Rules:**
- Do not create ad-hoc colors, spacings, corner radii, or typography.
- Use design tokens/components from the design system for **all UI** (SetupView, LiveView overlays, pickers, buttons, sliders, etc.).
- Keep UI minimal, but consistent.

### Integration (V1)

Add the design system as a dependency (preferred: **Swift Package Manager**):
1. In Xcode: *File → Add Packages…*
2. Paste the repo URL: `https://github.com/JarlLyng/iamjarl-design`
3. Add it to the **Echolume** app target.

### Usage conventions

- Import the module(s) provided by the package in SwiftUI views (exact module name depends on the package).
- Use token-based:
  - Colors (background/foreground/accent)
  - Typography (title/body/caption)
  - Spacing scale
  - Corner radius
  - Button/slider styles

If the design system exposes ready-made SwiftUI components (buttons, sliders, cards), use those first.

> If Cursor is unsure about module names, inspect the package sources after adding it in Xcode and follow the package’s README as source-of-truth.

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
3. Avoid third‑party deps for V1.
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

---

## Marketing site (GitHub Pages)

A one-page marketing site lives in **`docs/`** and can be hosted on GitHub Pages:

1. **GitHub** → repo **Settings** → **Pages**.
2. Under **Build and deployment**, **Source**: *Deploy from a branch*.
3. **Branch**: `main`, **Folder**: `/docs`. Save.

The site will be available at `https://<username>.github.io/echolume/` (or your custom domain if configured).

- **`docs/index.html`** — landing page (hero, features, download).
- **`docs/how-it-works.html`** — setup guide (mic, audio interface, BlackHole, troubleshooting).
- **`docs/privacy.html`** — privacy policy.
- **`docs/support.html`** — FAQ and contact (GitHub Issues).
- **`docs/styles.css`** — styles (Echolume accent colors, dark theme).
- **`docs/.nojekyll`** — disables Jekyll so static files are served as-is.

When the app is on the Mac App Store, replace the download CTA in `docs/index.html` with the App Store link.

- **Privacy policy:** `docs/privacy.html` → e.g. `https://JarlLyng.github.io/echolume/privacy.html` (use this URL in App Store Connect).
- **Support:** `docs/support.html` — FAQ and contact. Link from the App Store listing if you want.

---

## Sentry (error monitoring)

**Note:** Sentry is **on** for the test phase. Set `SENTRY_DSN` (and optionally `SENTRY_ENVIRONMENT`) in the scheme’s Environment Variables. Consider removing or disabling Sentry before App Store release. If the build fails with "Missing package product 'Sentry'", open the project in Xcode and run **File → Packages → Resolve Package Versions** (or **Reset Package Caches** first, then resolve).

**Setup:**

1. In [Sentry](https://sentry.io), create a project (e.g. **macOS** or **echolume**) and copy the DSN.
2. Run the app with the DSN set:
   - **Environment variable:** `SENTRY_DSN=https://…@….ingest.sentry.io/…`
   - Or in Xcode: **Edit Scheme** → **Run** → **Arguments** → **Environment Variables** → add `SENTRY_DSN`.
3. Optional: `SENTRY_ENVIRONMENT` (default `development`) to separate test/production.

Without `SENTRY_DSN`, the app runs as before; Sentry is simply not started.

---

## License

TBD.
