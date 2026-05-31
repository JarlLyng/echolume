# Changelog

All notable changes to Echolume are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Removed
- Sentry crash-reporting dependency. Echolume now relies on Apple's built-in
  crash reporting (Xcode Organizer / App Store Connect) — no third-party SDK.

### Added
- VoiceOver / accessibility support across the UI: adjustable knobs, labeled
  level meter, and labels on icon-only controls.
- Privacy-friendly, cookieless Umami analytics on the marketing site.

### Changed
- Updated the IAMJARL design-system package to 1.0.0.
- Spacebar = Randomize now triggers only in Live (on Setup, Space behaves
  normally instead of overwriting a dialed-in look).
- LiveView overlay redrawn with consistent scrims + light text so it stays
  legible over bright or dark visuals; Panic is now a prominent ≥44 pt button.

### Performance
- Removed a per-frame palette allocation and a per-call beat-tracker allocation;
  reduced realtime ring-buffer work (power-of-two masking + block copies).
- Off-screen Metal views now pause and honor the display's actual refresh rate.

### Fixed
- Marketing site: literal `**markdown**` rendering as visible asterisks; hero
  animation now respects `prefers-reduced-motion`; invalid JSON-LD placeholder
  removed and FAQ schema added to the guide pages.

## [1.0.0] — TestFlight beta

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
