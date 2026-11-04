# EcholumeAudioTap (AUv3)

An Audio Unit v3 audio effect bundled inside Echolume.app. Drop it on a track in
any AU host (Ableton Live, Logic Pro, etc.); it passes audio through unchanged
and forwards the analysed signal to Echolume over OSC (loopback), so the visuals
react to that track without a loopback driver such as BlackHole.

Installing Echolume.app auto-registers the plugin (no separate installer).

## What it sends

On a dedicated sender thread (never the realtime render thread), it forwards:

- the three bands (low/mid/high) and a full 64-bin spectrum, over
  `/echolume/audio/...`;
- the host tempo (BPM).

Enable **OSC Input** in Echolume's Setup (default port 9000) for the app to
receive it. The app suppresses its own microphone analysis while the plugin is
driving.

## Parameters

- **Output Gain** (0 to 1): a simple pass-through gain on the audio.

## Code layout

- `Parameters/` — the parameter tree (`Parameters.swift`) and C addresses.
- `DSP/EcholumeAudioTapDSPKernel.hpp` — the realtime C++ kernel (analysis +
  pass-through).
- `UI/` — the SwiftUI plugin view (`EcholumeAudioTapMainView.swift`,
  `ParameterSlider.swift`, `PluginStyle.swift`). The extension does not link the
  design-system package, so it uses local brand constants.
- `Common/` — AUv3 scaffolding (audio unit, parameter plumbing); rarely edited.

See the app's [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) for how the OSC
route fits the wider renderer, and the root [`README.md`](../README.md) for the
feature list.
