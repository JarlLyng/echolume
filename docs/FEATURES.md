# Echolume features

The complete feature guide. For the short version, the developer docs and how to build, see the [README](../README.md).

### Scenes and looks

Echolume has ten scenes (radial, flow, grid, spiral, tunnel, kaleidoscope, plasma, spectrum ring, ridgeline and wireframe burst), ten themes (Summer, Winter, Dark Ambient, Techno Club, Neon Lines, Monochrome, Sunset, Nebula, Vapor and Acid) and five shape styles (blobs, circles, lines, grid and particles). Five knobs shape the result: Abstraction, Energy Bias, Motion, Noise and Glitch. Decaying trails give the picture depth; Abstraction sets how long they last, and Panic Reset clears them. Randomize picks a new theme, shape, scene and knob positions in one go.

### Audio inputs

Echolume listens to audio inputs: your Mac's microphone, an audio interface or a loopback device. Pick any input and channel pair inside the app, without changing the macOS default. If the chosen input disappears mid-set, Echolume falls back to the default input instead of stopping. It does not capture your Mac's output directly, so music playing in another app needs a loopback driver such as BlackHole. macOS asks for microphone permission the first time, even when the input is an audio interface.

### From your DAW (beta)

`EcholumeAudioTap` is an AUv3 audio effect bundled inside Echolume.app, so installing the app registers it. Put it on a track in Ableton Live (11.3 or later), Logic Pro or another AU host, then turn on OSC input in the Control section of Echolume's Setup. OSC is off by default, and the plugin does nothing until it is on. The plugin passes the audio through untouched and sends that track's bands, a 64-bin spectrum and the host tempo to Echolume over OSC on the same Mac (port 9000), so every scene follows the track with no loopback routing.

### Tempo

Echolume finds the tempo of what it hears (80 to 180 BPM) and adds a small brightness pulse on the beat once it has locked on. The Tempo tile in Setup shows the BPM and whether it is locked. If it locks onto the wrong beat, tap the tempo in with the **Tap** button or a MIDI note, and the **Manual** toggle holds it. With the DAW plugin it uses the host tempo instead.

### Presets

A preset saves the theme, shape style, scene and all five knobs. Save one from the Presets section in Setup (names are unique), recall it by clicking it, with `⌘1` to `⌘9` for the first nine, or from Twitch chat with `!preset <name>`, and delete it from its context menu. Presets persist across launches.

### MIDI

MIDI Learn works with any class-compliant MIDI controller. In the MIDI tile, turn on Learn, click a knob and move a control on your controller to bind it; the knob then shows a `CC n` badge. The Learn buttons bind notes to Randomize, Panic Reset, Next Theme, Previous Theme and Tap Tempo. To try it without hardware, use the IAC Driver in Audio MIDI Setup.

### OSC

Echolume can listen for OSC over UDP, so it fits into a TouchDesigner or Resolume rig. It is off until you turn it on in the OSC tile, where you also set the port (9000 by default). Every address starts with `/echolume/`:

| Address | Effect |
|---------|--------|
| `knob/<knob>` | Sets a knob to a float from 0 to 1. The knobs are `abstraction`, `energybias`, `motion`, `noise` and `glitch`. |
| `theme` | Selects a theme by index (int, from 0) |
| `scene` | Selects a scene by index (int, from 0) |
| `shape` | Selects a shape style by index (int, from 0) |
| `nexttheme` | Next theme |
| `prevtheme` | Previous theme |
| `randomize` | Randomize |
| `panic` | Panic Reset |
| `tempo/tap` | Taps the tempo |
| `preset` | Recalls a preset by slot (int, from 1) or by name (string) |

For example, `/echolume/knob/abstraction 0.8` sets Abstraction to 80%.

### Twitch chat

Turn on Twitch Chat in Setup and enter a channel name. Echolume joins that channel's chat anonymously and read-only, without signing in, and takes one command per second. The status light shows the connection state.

| Command | Effect |
|---------|--------|
| `!theme <name>` | Switches theme by name, for example `!theme summer` or `!theme techno club` |
| `!scene <name>` | Switches scene: `radial`, `flow`, `grid`, `spiral`, `tunnel`, `kaleidoscope`, `plasma`, `spectrumring`, `ridgeline`, `wireframeburst` |
| `!shape <name>` | Switches shape style: `blobs`, `circles`, `lines`, `grid`, `particles` |
| `!randomize` | Randomizes the look |
| `!glitch` | Toggles Glitch between high and low |
| `!abstract <0–100>` | Sets Abstraction |
| `!preset <name>` | Recalls a saved preset by name |

### Live and output

Hit **Ready** to go Live: the visuals fill the screen and the small overlay hides while the mouse is still. Pick an external display in Setup to put the visuals on a projector while the controls stay on your laptop. A menu bar item has Randomize, Panic Reset, Restart Audio and Open Echolume, so they stay in reach while Echolume runs fullscreen on another display.

| Key | Action |
|-----|--------|
| Return | Goes Live from Setup, and back to Setup from Live |
| Esc | Leaves Live |
| Space | Randomize (in Live) |
| R | Panic Reset, which clears the trails |
| ⌘R | Restarts audio |
| V | Starts or stops recording (in Live) |
| 1 to 9, 0 | Selects theme 1 to 10 |
| ⌘1 to ⌘9 | Recalls preset 1 to 9 |

### Recording

Press **V** or **Record** in Live to record the output to an H.264 `.mp4` in your Movies folder. The file has the picture only, with no audio track, so pair it with your own recording of the music in an editor, or capture both together in OBS.

### Privacy

Audio is analysed in memory and never stored or sent anywhere. Only the optional Twitch chat connects to the internet. There is no analytics or crash-reporting SDK; crash reports reach the developer through Apple only if you share analytics with developers in macOS. The full policy is at [echolume.iamjarl.com/privacy.html](https://echolume.iamjarl.com/privacy.html).

### Support

Questions, bugs and feedback go to **support@iamjarl.com**, or **Help → Send Feedback…** in the app (from the release after 1.3.0), which fills in your Echolume and macOS versions. GitHub issues are welcome too, for anything you would rather discuss in public.
