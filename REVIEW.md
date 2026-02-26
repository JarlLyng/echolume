# Review af Echolume (26. feb 2026)

**Kort opsummering**
Appen har en solid grundstruktur (audio → mapping → render), men der er flere funktionelle huller og et par performance‑risici i audio‑pathen, som kan give dropouts eller uventet adfærd i UI’et. Der mangler også tests for de mest kritiske dele.

**Findings (Høj)**
- **Real‑time‑kritiske operationer i audio‑callback**: I tap‑callbacken tages locks og der oprettes en `DispatchWorkItem` pr. tap. Det kan give dropouts under belastning. Se `echolume/Audio/AudioManager.swift:178-225` og `echolume/Audio/AudioManager.swift:250-255`.
- **“Automatic” device skifter ikke faktisk input**: Når brugeren vælger “Automatic”, restartes audio‑engine ikke, så den bliver stående på sidste valgte device. Se `echolume/App/AppModel.swift:397-405`.

**Findings (Mellem)**
- **Flere UI‑kontroller påvirker ikke shaderen**: `shapeStyleIndex`, `shapeCount`, `warpAmount`, `trailPersistence` og `reactivity` beregnes og sendes til shaderen, men bruges ikke i rendering. Det betyder at “Shape”, “Abstraction” og “Energy Bias” i praksis har minimal eller ingen effekt. Se `echolume/Visuals/ParamMapping.swift:97-134` og `echolume/Renderer/Shaders.metal:20-33`.
- **Debug‑tint er aktiv i produktion**: Shaderen tinter output, når `motion/noise/glitch > 0.8`, hvilket ændrer visuals i normal brug. Se `echolume/Renderer/Shaders.metal:311-314`.

**Findings (Lav)**
- **Ubrugte filer**: `ContentView.swift` bruges ikke, hvilket skaber støj i projektet. Se `echolume/ContentView.swift`.
- **Tema‑defaults bliver ikke anvendt ved themeskift**: `Theme.defaultShapeStyle` anvendes aldrig, så themespecificerede defaults slår ikke igennem. Se `echolume/Visuals/Theme.swift:15-24` og `echolume/App/AppModel.swift:437-451`.

**Testmangler**
- Ingen tests for `AudioManager` (device‑skift, restart‑debounce, FFT‑pipeline) eller `ParamMapping` (glitch/impulse/abstraction). Se `echolumeTests/echolumeTests.swift`.

**Åbne spørgsmål/antagelser**
- Jeg antager at “Randomize” kun skal ændre seed, men README beskriver randomize af theme/parametre. Hvis produktkravet er bredere, bør `randomize()` udvides.

**Anbefalinger (prioriteret)**
1. Gør audio‑callback realtime‑sikker: undgå `DispatchWorkItem`‑allokeringer og locks i tap; brug fx en lock‑free ringbuffer + atomisk flag til FFT‑arbejde på baggrundstråd.
2. Fix “Automatic” device: restart audio med `nil` deviceID når brugeren vælger Automatic.
3. Wire UI‑kontroller til shaderen: brug `shapeStyleIndex` og `shapeCount` til at vælge/forke shape‑funktioner, og brug `warpAmount`, `trailPersistence` og `reactivity` i scene‑logikken.
4. Fjern eller debug‑guard shader‑tint (kun i DEBUG eller bag feature‑flag).
5. Tilføj tests for `AudioManager` og `ParamMapping`, især edge cases for device‑skift og glitch/impulse‑logik.
