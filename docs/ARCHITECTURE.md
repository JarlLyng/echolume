# Echolume — Architecture & design notes

This document describes Echolume's intended design, layering, type contracts, and
development conventions. It is the reference contributors should follow when
extending the app. For the product overview, features, and setup, see the
[README](../README.md).

> This README/ARCHITECTURE split exists because the README previously mixed
> shipped features with target architecture. Shipped features and usage live in
> the README; design intent and contracts live here.

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

## Architecture

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

```
enum SceneType {
    case radial
    case flow
    case grid
    case spiral
    case tunnel
    case kaleidoscope
    case plasma
    case spectrumRing
}
```

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

## Development notes

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
- Complex beat grid detection
- Video recording/export
- Twitch OAuth / authenticated connections (anonymous read-only is sufficient for V1)
