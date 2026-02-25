# Echolume – teknisk review (macOS)

Dato: 25. februar 2026

## Overordnet vurdering
Arkitekturen er tydeligt opdelt i Audio → Mapping → Scene → Render, hvilket er godt og gør systemet udvideligt. UI-laget er slankt, og parametre sendes via en tråd-sikker provider til renderer. Der er dog nogle alvorlige samtidigheds- og performance‑risici i audio‑pipen, samt et test‑gap som gør regressioner svære at opdage.

## Fund (prioriteret)

### Kritisk / Høj risiko
1. Datakapløb i ringbuffer og indeksere (audio callback vs. FFT‑thread)
   - I `echolume/Audio/AudioManager.swift` skrives `ringBuffer`, `ringWriteIndex` og `ringReadIndex` i audio‑tappen uden lås, mens `runFFT()` læser dem under `ringLock`. Det er ikke tråd‑sikkert og kan give corrupted data eller crash.
   - Forslag: Brug en lock/atomic rundt om både write og read, eller implementér en lock‑fri ringbuffer med atomiske indeksere (fx `ManagedAtomic<Int>`). Hvis lock bruges i tap‑callback, hold den ultrakort og undgå allokeringer.

2. Delte værdier læses uden synkronisering
   - `_rms`, `_peak`, `_frameCount`, `_channelCount` opdateres i tap‑callback og læses fra main thread (timer). Det er datakapløb i Swift og ikke garanteret sikkert.
   - Forslag: Brug atomics, en lock eller kopier disse værdier via en tråd‑sikker queue.

### Medium risiko
1. FFT‑processen allokerer for hvert kald
   - `FFTProcessor.process(samples:)` opretter `windowed` som en ny array for hvert kald (i `echolume/Audio/FFT.swift`). Det er imod kommentaren om “no allocations” og kan give GC‑/ARC‑overhead og stutter under load.
   - Forslag: Gem `windowed` som et genbrugeligt buffer‑array i `FFTProcessor`.

2. Audio status kan være misvisende
   - `AppModel.requestMicrophonePermissionAndStartAudio()` sætter `audioStatus = .running`, men der er ingen reel feedback fra `AudioManager` om start‑success. Hvis engine start fejler, UI kan stadig vise “running”.
   - Forslag: Tilføj en callback/publisher fra `AudioManager` for start‑status og fejl, og opdatér `audioStatus` baseret på faktisk start.

3. Renderer og MTKView bruger potentielt forskellige `MTLDevice`
   - `MetalView.makeNSView()` og `Coordinator` laver hver sin `MTLCreateSystemDefaultDevice()`. Det giver normalt samme device, men det er ikke garanteret (f.eks. eGPU/Multiple GPUs).
   - Forslag: Brug `view.device` til at bygge `Renderer`, og init kun én gang.

### Lav risiko / polish
1. AudioAnalyzer har publishers for RMS/peak som ikke bruges
   - `AudioAnalyzer` sender `rmsPublisher` og `peakPublisher`, men UI læser i stedet `AudioManager.debugLastRMS`. Overvej at konsolidere for at undgå dobbelt‑beregning og kompleksitet.

2. `Theme.nudgedPalette` har ubrugte beregninger
   - Variablen `hueShift` beregnes men bruges ikke i `echolume/Visuals/Theme.swift`.

## Anbefalinger (konkrete)
1. Fix samtidighed i audio‑pipen først
   - Implementér en tråd‑sikker ringbuffer med atomiske indeksere, eller brug en kort lock både i tap og `runFFT()`.
   - Løs også data‑race på `_rms/_peak/_frameCount`.

2. Reducér FFT‑allokeringer
   - Gør `windowed` til en genbrugsbuffer i `FFTProcessor`.

3. Giv `AudioManager` klar status og fejl‑kanal
   - Et simpelt `@Published`/Combine‑publisher for `engineRunning` og `lastError` (eller en callback) vil gøre UI‑status mere korrekt.

4. Saml Metal device‑init
   - Brug `MTKView.device` i `MetalView` til at oprette `Renderer`.

5. Test‑strategi (minimalt men værdifuldt)
   - Unit tests for `ParamMapping` (deterministiske outputs for kendte inputs og seed).
   - Unit tests for `FFTProcessor`/`magnitudeSpectrumToBands` (små syntetiske signaler, forventede band‑levels).

## Test‑gap
Der er i praksis ingen tests (kun en tom testfil). Det øger risikoen for regressions i mapping, audio‑routing og rendering.

## Residual risiko
Selv med ovenstående fixes vil audio‑pipeline være følsom overfor specifikke CoreAudio‑enheder og sample‑rate‑mismatch. Det er normalt, men bør profileres på mindst 2‑3 forskellige interfaces.

---
Hvis du vil, kan jeg implementere de konkrete fixes (ringbuffer‑synkronisering + FFT‑buffer + status‑publisher) i en næste iteration.
