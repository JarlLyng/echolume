# Echolume

A macOS app for **live, audio‑reactive 2D visuals** rendered with **Metal**. Echolume is meant as a **performance tool**: select an audio input source (audio interface inputs, loopback inputs, mic, etc.), pick a visual theme, set an “abstraction” level, hit **Ready**, and perform.

> Design goals: **stable**, **low‑latency**, **minimal UI**, **beautiful results with few controls**, and a **clean architecture** that Cursor can extend deterministically.

---

## Product vision

Echolume turns sound into light.

**User flow (V1):**
1. Open the app.
2. Choose **Audio Source** (input device + channel pair).
3. Choose a **Theme** (or press **Randomize**).
4. Set **Abstraction** (single slider controlling multiple internal parameters).
5. Press **Ready** → fullscreen (optionally on an external display) and visuals react to audio.

**Important constraints (App Store friendly):**
- Echolume captures **audio input** only (via CoreAudio/AVAudioEngine). It does **not** capture “system audio” directly.
- Requires **Microphone** permission (even for audio interfaces on macOS in practice).

---

## V1 scope (ship‑able)

### Must‑have
- **Metal renderer** for 2D visuals (single fullscreen pass + optional trail/feedback pass).
- **Audio engine** that:
  - enumerates input devices
  - allows selecting **stereo channel pair** (e.g. 1–2, 3–4)
  - provides a live **input meter** (RMS + peak)
  - runs a lightweight **FFT** (at least 3 bands: low/mid/high)
- **Setup screen** (SwiftUI):
  - Audio Source picker
  - Theme picker
  - Abstraction slider
  - Randomize button
  - Ready button
- **Live screen**:
  - Fullscreen Metal output
  - Minimal overlay (ESC/Back, tiny audio meter)

### Nice‑to‑have (after V1)
- External display picker (“Output Display”).
- Presets (save/load theme + abstraction + seed).
- Additional analysis: onset detection, beat estimation.
- Multiple scenes.

---

## Architecture (Cursor should follow this)

Keep the system in **three layers** with clear boundaries:

1) **Audio** (input + analysis)
2) **Mapping** (turn analysis into normalized params)
3) **Render** (Metal draws frames using params)

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
- Default to the **last used** device/channel/theme (persist in `UserDefaults`).
- Show a clear “Signal detected” indicator.

### LiveView
- Fullscreen (toggle) with minimal chrome.
- ESC exits fullscreen; `⌘.` or Back button exits Live.

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

### Milestone 2 — Audio input works
- Device picker
- Permission prompt
- Live meter (rms/peak)

### Milestone 3 — Audio → visuals
- FFT bands
- ParamMapping
- 2–3 procedural visual styles

### Milestone 4 — Themes + Randomize
- Theme library
- Randomization seed
- Persist last used settings

### Milestone 5 — Live readiness
- Fullscreen stability
- External display support (optional)
- Performance tuning (FPS stable, no stutters)

---

## Development notes for Cursor

When implementing, follow these rules:

1. **Small, testable steps**. Prefer compiling after each file.
2. Keep SwiftUI views dumb; most logic goes into `AppModel` and subsystems.
3. Avoid third‑party deps for V1.
4. Prefer deterministic code (no hidden magic).
5. Add lightweight logging around audio start/stop and device selection.

---

## Out of scope for V1

- Capturing system audio output without routing
- MIDI input
- Complex beat grid detection
- Video recording/export

---

## License

TBD.
