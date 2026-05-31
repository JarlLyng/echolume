# Echolume — Onboarding

Live, audio‑reactive 2D visuals for macOS, rendered with Metal. SwiftUI app; ships to TestFlight/App Store. This is the quick orientation for a new developer (or AI session). See `README.md` for product detail and `CONTRIBUTING.md` for setup/style.

## What it is
A performance/VJ tool: pick an audio input, a theme/scene/shape, tweak 5 performance knobs, hit **Ready**, perform. Visuals react to audio (FFT bands, beat) and can be driven from multiple input sources.

## Build / run / test
- **Requires:** macOS 14+, Xcode 16+. First local build needs the Metal toolchain: `xcodebuild -downloadComponent MetalToolchain` (one‑time, ~688 MB).
- **Build:** `xcodebuild -project echolume.xcodeproj -scheme echolume build`
- **Test:** `xcodebuild -project echolume.xcodeproj -scheme echolume test` (quit any running `echolume.app` first, or the stock UI tests flake on "automation mode").
- Swift 5 language mode (`SWIFT_VERSION = 5.0`) with `-default-isolation=MainActor`.

## Repo layout (where things live)
- `echolume/Audio/` — capture + analysis: `AudioManager`, `AudioAnalyzer`, `FFT`, `BeatTracker`.
- `echolume/Visuals/` — `Theme`, `SceneType` (7 scenes), `ShapeStyle`, `ParamMapping`, `VisualParams(Provider)`, `Preset(Store)`.
- `echolume/Renderer/` — `Renderer.swift` (two‑pass ping‑pong feedback/trails), `Shaders.metal` (scenes + `ShaderUniforms`, kept in lockstep — a stride test guards it).
- `echolume/App/` — `AppModel` (central state + input dispatch), `EcholumeApp`, `TwitchChatManager`, `MenuBarController` (AppKit NSStatusItem), `PresetStore`.
- `echolume/MIDI/`, `echolume/OSC/` — control inputs (MIDI Learn; OSC `/echolume/...` listener on port 9000).
- `echolume/UI/` + `echolume/UI/Sections/` — one `*Section.swift` per Setup card; `Components/KnobView.swift`.
- `EcholumeAudioTap/` — **AUv3 audio plugin** (separate Xcode target, bundled in the app): C++ DSP kernel + Swift wrapper; taps DAW audio and sends `/echolume/audio/*` OSC to the app.
- `echolumeTests/` — Swift Testing unit tests (pure logic: parsing, mapping, stores, beat). `echolumeUITests/` — stock launch tests.

## Implemented features
Audio engine + in‑app device switching; 6 themes × 7 scenes × 5 shapes + 5 knobs + Randomize; feedback/decaying trails; beat detection (autocorrelation BPM + tap tempo); preset system (save/recall/delete, ⌘1–9); MIDI Learn; OSC input; menu bar extra; the AUv3 audio‑tap plugin (beta). Crash reporting via Apple's built‑in tooling (Xcode Organizer / App Store Connect) — no third‑party SDK.

## Shipping to TestFlight
Xcode Organizer: **Product → Archive** (destination "Any Mac") → **Distribute App → TestFlight & App Store Connect → Upload**. Automatic signing, team `KDWZ3WNLDK`, bundle `com.iamjarl.echolume`. Bump `CURRENT_PROJECT_VERSION` (all app‑target configs, replace_all) before each upload. See the `echolume-release-state` memory for the last uploaded build number.

## Gotchas (cost real time before)
- **CI uses an older toolchain than a bleeding‑edge local Xcode.** Don't assume local‑compiles == CI‑compiles for actor‑isolation syntax (e.g. `nonisolated` on a type fails on CI). A newly Xcode‑generated target may get future deployment targets (`MACOSX_DEPLOYMENT_TARGET = 26.5`, multi‑platform) that CI's Xcode 16 can't build — make new targets match the app (`14.0`, `SDKROOT = macosx`, `SUPPORTED_PLATFORMS = macosx`).
- **A GitHub Actions billing block looks like a code failure:** both jobs FAILURE instantly, no steps, `--log` returns BlobNotFound. Check `gh api repos/<o>/<r>/check-runs/<jobId>/annotations`. Fall back to the local CI‑style build/test (see `echolume-build-env` memory).
- **GUI/Ableton can't be driven by automation here** (SwiftUI AX is unreliable; Screen Recording is denied). Lean on unit tests + `auval` for plugins, and ask the user for visual/Ableton confirmation.
- The audio plugin sends OSC from the **render thread** (best‑effort, non‑blocking) — a known v2 hardening item; an earlier cross‑thread timer segfaulted Ableton.

## Open backlog
- Issues: #4 Twitch OAuth (out of V1 scope), #6 video recording, #9 Danish localization.
- Plugin v2 (#46 follow‑ups): move OSC transport off the realtime thread; derive beat phase from host PPQ; confirm App Store review of the bundled AUv3 + UDP socket.
- Possible visual polish: dedicated Trails knob, replace the Circles shape stub, enforce per‑theme shape restrictions, bloom/post‑FX.
