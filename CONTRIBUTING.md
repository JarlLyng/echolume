# Contributing to Echolume

Thanks for considering a contribution! Echolume is a small, focused macOS app for live audio-reactive visuals. The project values **stability, minimal UI, and a clean architecture** over feature count.

## Before you start

- Open or comment on an [issue](https://github.com/JarlLyng/echolume/issues) before starting non-trivial work — it saves both of us time.
- For bugs, use the **Bug report** template.
- For features, use the **Feature request** template.
- Trivial fixes (typos, doc tweaks) can go straight to a PR.

## Development setup

### Requirements
- macOS 14 (Sonoma) or later
- Xcode 16 or later (builds in Swift 5 language mode via the Xcode 16 toolchain)

### Getting the code

```bash
git clone https://github.com/JarlLyng/echolume.git
cd echolume
```

### Build and run

Open `echolume.xcodeproj` in Xcode and press **Run**, or:

```bash
xcodebuild -project echolume.xcodeproj -scheme echolume build
```

### Run tests

```bash
xcodebuild -project echolume.xcodeproj -scheme echolume test
```

## Architecture overview

See [README.md](README.md#architecture) for the layered architecture (Audio → Analysis → State → Rendering). When adding features:

- **Audio capture / analysis / beat** → `echolume/Audio/` (`AudioManager`, `AudioAnalyzer`, `FFT`, `BeatTracker`)
- **Shaders / scenes / feedback-trails** → `echolume/Renderer/` (`Shaders.metal`, `Renderer.swift` — two-pass ping-pong feedback)
- **Visual model / params / themes / presets** → `echolume/Visuals/` (`Theme`, `SceneType`, `ShapeStyle`, `ParamMapping`, `VisualParams(Provider)`, `Preset`)
- **State / parameters / input dispatch** → `echolume/App/AppModel.swift` (central hub)
- **UI** → `echolume/UI/` and `echolume/UI/Sections/` (one `*Section.swift` per Setup card)
- **Control inputs:** Twitch → `echolume/App/TwitchChatManager.swift`; MIDI → `echolume/MIDI/`; OSC → `echolume/OSC/`; menu bar → `echolume/App/MenuBarController.swift`
- **Audio plugin (AUv3)** → `EcholumeAudioTap/` (separate Xcode target, bundled in the app; C++ DSP kernel + Swift wrapper; sends `/echolume/audio/*` OSC)

Use the `IAMJARLDesignTokens` SPM package for all colors, spacing, and typography. Don't hardcode values.

## Code style

- Idiomatic Swift (Swift 5 language mode)
- `@MainActor` isolation for UI and state
- `Log` (via `os.Logger`) instead of `print()`
- No force-unwraps unless guarded by a precondition the compiler can't see
- Wrap debug-only code in `#if DEBUG`

## Pull requests

1. Fork the repo and create a branch from `main`
2. Make focused, single-purpose commits
3. Update relevant docs (README, marketing site, etc.) if behaviour changes
4. Fill out the PR template (test plan checklist matters)
5. Ensure the build succeeds and tests pass

## Reporting security issues

Please **do not** open public issues for security vulnerabilities. See [SECURITY.md](SECURITY.md).

## License

By contributing, you agree your contributions will be licensed under the [MIT License](LICENSE).
