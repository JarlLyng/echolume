# App Store description

The description for the **next version** submitted to App Store Connect. It is version-locked:
it can only be edited alongside a submission, so paste it in when the next version goes up
(`RELEASE_CHECKLIST.md`, section 2).

Starting point: the live 1.3 listing, read from the public iTunes lookup on 2026-10-08. Only what
was wrong or broke `VOICE.md` has changed. The positioning is untouched.

## Text to paste

```text
Echolume turns sound into light.

A focused macOS performance tool for live, audio-reactive 2D visuals, rendered with Metal for smooth, low-latency output. Pick an audio input, choose a look, tweak a few knobs, hit Ready, and perform.

Built for the stage and the stream
• 10 scenes (radial, flow, grid, spiral, tunnel, kaleidoscope, plasma, spectrum ring, ridgeline, wireframe burst) across 10 curated themes
• Real-time FFT + beat detection drive subtle, tempo-synced motion
• Decaying feedback trails for depth and flow
• Fullscreen output to any external display
• Record the output to an MP4 in your Movies folder (picture only, no audio track)

Plays well with your rig
• MIDI Learn: bind any controller to the performance knobs and triggers
• OSC input for TouchDesigner / Resolume setups
• Bundled AUv3 plugin: forward analysed bands + host BPM straight from your DAW, no loopback driver needed (turn on OSC input in Setup)
• Twitch chat integration for interactive streams
• Presets with ⌘1–9 recall, a menu bar extra, and one-tap Panic Reset

Made to stay out of the way
Minimal UI, stable by design, beautiful results from few controls.

Pay once. Yours forever.
```

## What changed from the live 1.3 text, and why

| Live 1.3 | Next version | Why |
|---|---|---|
| `2D visuals — rendered with Metal` | `2D visuals, rendered with Metal` | Em-dash in prose (#174, VOICE.md) |
| `MIDI Learn — bind …` | `MIDI Learn: bind …` | Bullet labels take a colon (#174, VOICE.md, settled 2026-09-05) |
| `Bundled AUv3 plugin — forward …` | `Bundled AUv3 plugin: forward …` | Same |
| `7 scenes (…) across 6 curated themes` | `10 scenes (…) across 10 curated themes` | Counts from 1.0; the app has had 10 of each since 1.3 (#177) |
| no mention of recording | `Record the output to an MP4 … (picture only, no audio track)` | Shipped in 1.2, and the silent-video limit stated plainly (#177) |
| `(no loopback driver needed)` | `…, no loopback driver needed (turn on OSC input in Setup)` | `oscEnabled` defaults to `false`, so the plugin alone does nothing (#178) |

`⌘1–9` keeps its en-dash: VOICE.md bans em-dashes, and a numeric range is what an en-dash is for.

## Not changed, worth deciding before submitting

- **The opening leads with the category, not the outcome.** #174 notes it: the first lines are what
  someone still deciding reads, and a paying customer's reason to buy was "simple first and
  foremost". The site's hero now leads with the outcome (#176). The store could follow.
- **"Pay once. Yours forever." sits at the very end.** VOICE.md wants the no-subscription line
  early and plain. The App Store already shows the price above the description, so this is a
  smaller gap than on the site.
- **What's New** for the next version is separate and not drafted here. It will need the Help menu's
  Send Feedback (#206) if that version carries it.
