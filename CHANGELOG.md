# Changelog

All notable changes to Echolume are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1]

### Added
- In-app App Store review prompt: asked on a positive moment (after a real
  Live session), never at launch, and at most once per 120 days (#97).
- First-run callout in the Control section pointing at MIDI Learn, OSC/Twitch,
  and presets; MIDI mapping hint now shows before Learn is enabled (#72).

### Changed
- The bundled AUv3 plugin now sends its OSC analysis from a dedicated ~60 Hz
  sender thread instead of the realtime audio render thread, eliminating a
  possible source of audible dropouts (#51).
- OSC and Twitch command hints are easier to read (higher contrast), and
  residual hardcoded design values now use tokens/named constants (#71, #72).

### Fixed
- Out-of-range OSC scene/shape indices are clamped instead of ignored (#67).
- A failed trail-clear is retried next frame instead of leaving stale trails
  (#67).
- The plugin's last BPM no longer lingers after it stops feeding audio (#67).
- FFT setup failure is now logged instead of silently degrading to RMS-only
  visuals (#68).
- Twitch chat now detects silently dropped connections (liveness probe) and
  keeps reconnecting with exponential backoff instead of giving up (#69).

## [1.0.0] — Mac App Store release (Jul 2026)

First public release (app id 6759684323). Changes since the TestFlight beta:

### Removed
- Sentry crash-reporting dependency. Echolume now relies on Apple's built-in
  crash reporting (Xcode Organizer / App Store Connect) — no third-party SDK.

### Added
- VoiceOver / accessibility support across the UI: adjustable knobs, labeled
  level meter, labeled pickers, and labels on icon-only controls.
- Spectrum Ring scene (N-bin FFT spectrum to the shaders) — an 8th scene.
- New square-wave app icon (dark full-bleed variant as the default).
- Privacy manifest (`PrivacyInfo.xcprivacy`) declaring required-reason API use.
- Privacy-friendly, cookieless Umami analytics on the marketing site.

### Changed
- Updated the IAMJARL design-system package to 1.1.0.
- Spacebar = Randomize now triggers only in Live (on Setup, Space behaves
  normally instead of overwriting a dialed-in look).
- LiveView overlay redrawn with consistent scrims + light text so it stays
  legible over bright or dark visuals; Panic is now a prominent ≥44 pt button.

### Performance
- Removed a per-frame palette allocation and a per-call beat-tracker allocation;
  reduced realtime ring-buffer work (power-of-two masking + block copies).
- Off-screen Metal views now pause and honor the display's actual refresh rate.

### Fixed
- Audio input auto-selection preferred the alphabetically-first device, which
  could land on a silent loopback driver (e.g. BlackHole) and read as a
  permanent "No signal". Now prefers the system default input.
- Marketing site: literal `**markdown**` rendering as visible asterisks; hero
  animation now respects `prefers-reduced-motion`; invalid JSON-LD placeholder
  removed and FAQ schema added to the guide pages.

## [1.0.0-beta] — TestFlight beta

Initial feature-complete beta (TestFlight). Highlights:

### Added
- Metal renderer for live 2D audio-reactive visuals with a two-pass
  feedback/decaying-trail accumulation.
- Audio engine: input-device enumeration and in-app switching, stereo
  channel-pair selection, safe fallback, live RMS/peak meter, and FFT bands.
- 6 themes, 7 scenes, 5 shape styles, 5 performance knobs, and Randomize.
- Beat detection (autocorrelation BPM + beat-phase tracking) with tap-tempo.
- Preset system: save/recall/delete, `⌘1`–`⌘9`, and the `!preset` chat command.
- MIDI Learn: bind CCs to knobs and notes to Randomize/Panic/theme actions.
- OSC input: opt-in UDP listener mapping a `/echolume/…` namespace to controls.
- Twitch chat integration (anonymous read-only IRC, viewer commands).
- External-display output selection and a menu-bar extra with quick actions.
- `EcholumeAudioTap` AUv3 plugin (beta): forwards analysed bands + host BPM to
  Echolume over OSC.

[Unreleased]: https://github.com/JarlLyng/echolume/compare/main...HEAD
