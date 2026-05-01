# Codex-anbefalinger til Echolume

Review udført 2026-05-01 med fokus på koncept, kode, dokumentation og GitHub-opsætning.

## Kort konklusion

Echolume har et klart og interessant udgangspunkt: en fokuseret macOS-performanceapp til audio-reactive visuals, med et fornuftigt V1-scope og en arkitektur der allerede er delt op i audio, mapping, visuals, renderer og UI. Projektet er længere end en prototype: der er CoreAudio-device switching, Metal-rendering, Twitch IRC, ekstern display-support, GitHub Pages, issue templates, CI og basal testdækning.

De vigtigste næste skridt er ikke flere features. De er at gøre release-grundlaget mere robust:

1. Fjern Sentry-URL'en fra den delte Xcode scheme, roter den hvis den er reel, og ret `SENTRY_DNS`/`SENTRY_DSN`-mismatch.
2. Luk thread-safety hullerne i audio-state og realtime-tap.
3. Ret Twitch-channel flowet, så typing i feltet ikke reconnecter på hvert tastetryk.
4. Beskyt `main`, aktiver dependency/security scanning og stram CI op.
5. Ensret docs med den faktiske custom domain, buildkonfiguration og appadfærd.

## Prioriteret handlingsplan

| Prioritet | Anbefaling | Hvorfor |
| --- | --- | --- |
| P0 | Fjern Sentry ingest URL fra `echolume.xcodeproj/xcshareddata/xcschemes/echolume.xcscheme`, roter den hvis den bruges, og brug kun `Sentry.xcconfig`/scheme-local env vars. | Den delte scheme indeholder en Sentry-URL og nøglen er stavet `SENTRY_DNS`, mens appen læser `SENTRY_DSN`. Det er både en konfigurationsfejl og et leakage-signal. |
| P0 | Gør `AudioManager` state trådsikker: `engine`, `lastError`, `formatSampleRate`, `formatChannelCount`, `selectedChannelPairIndex` og `debounceWorkItem` bør læses/skrives via samme serial queue, lock eller immutable snapshot. | `AppModel` poller disse fra main hvert 100 ms, mens `AudioManager` muterer dem på audio queue. Det kan give race conditions og sporadisk forkert UI/status. |
| P0 | Undgå blocking `NSLock` i audio tap. Brug lock-free ringbuffer, atomics, tryLock/drop-frame-strategi eller en enkelt-producer/enkel-consumer buffer. | Callbacken holder `ringLock` mens den skriver samples, og FFT-queue holder samme lock mens den kopierer 2048 samples. Det kan blokere realtime audio. |
| P0 | Ret Twitch channel editing, så `setTwitchChannel` ikke kalder `connectTwitch()` på hvert tegn. | `TextField` skriver gennem bindingen for hvert tastetryk; lige nu kan appen oprette og afbryde WebSocket-forbindelser gentagne gange under indtastning. |
| P0 | Beskyt `main` med required PR, required `Build and Test`, og helst linear history. | GitHub API returnerede `Branch not protected` for `main`, mens Pages publicerer direkte fra `main/docs`. |
| P1 | Tilføj tests for FFT, ParamMapping, uniform layout, randomize, UserDefaults persistence og Twitch state. | Den nuværende testpakke dækker primært Twitch command parsing. De risikable dele er audio/mapping/render-kontrakterne. |
| P1 | Ret canonical/OG/sitemap/support-links fra `https://JarlLyng.github.io/echolume/` til `https://echolume.iamjarl.com/`. | GitHub Pages er sat op med custom domain `echolume.iamjarl.com`, men metadata peger stadig på GitHub Pages-subpathen. |
| P1 | Tilføj `set -o pipefail`, `permissions: contents: read` og `concurrency` i GitHub Actions. | CI bliver mere pålidelig, mere sikker og spilder færre runner-minutter. |
| P1 | Aktiver Dependabot alerts, tilføj `.github/dependabot.yml`, og aktiver code scanning/secret scanning hvor muligt. | GitHub API viste at Dependabot alerts og code scanning ikke er aktiveret. |
| P2 | Afstem README/CONTRIBUTING med faktisk kode: mapper, randomize-adfærd, Swift-version, Sentry-status og custom domain. | Dokumentationen er god, men nogle dele beskriver ønsket design frem for nuværende implementation. |

## Koncept og produkt

### Det stærke

- Produktidéen er tydelig: "sound into light" som live-performanceværktøj til macOS.
- Scope er fornuftigt afgrænset: audio input, få performance-knobs, themes/scenes, fullscreen og ekstern display.
- App Store-begrænsningen om ikke at fange system audio direkte er tydeligt dokumenteret i `README.md`.
- Twitch integrationen passer godt til streaming-positioneringen.
- Projektet har allerede en marketing-/supportflade i `docs/`, hvilket er stærkt for en app der kræver routing og permissions.

### Anbefalinger

1. Vælg om repoet skal være open source eller privat produktrepo.
   GitHub-repoet er privat, men README, GitHub Pages, supportlinks og badges er skrevet som et offentligt open source-projekt. Enten gør repoet offentligt ved launch, eller juster marketing/support-flowet så brugere ikke sendes til private GitHub-sider.

2. Definer "V1 ship-ready" som en kort checklist.
   README har milestones, men en release checklist bør være mere operationel: build på clean machine, no-signal flow, device switching, BlackHole, OBS, Twitch, external display, crash reporting/privacy, signed/notarized build og release notes.

3. Afklar Sentry før release.
   `README.md` siger, at Sentry er aktiv i testfasen og bør overvejes fjernet før App Store release. `docs/privacy.html` siger samtidig at appen bruger Sentry til crash reporting og performance monitoring. Beslut om Sentry er opt-in, test-only eller produktionsfeature, og skriv det ens i app, README og privacy policy.

4. Gør Randomize-kontrakten entydig.
   README siger at Randomize bør holde sig inden for theme constraints og ændre seed; Twitch-dokumentationen siger random combination af theme, scene og shape; koden ændrer kun `seed`. Vælg én adfærd og gør app, README og webdocs ens.

5. Overvej minimumskontrol for Twitch.
   "Alle seere kan styre visuals" er et godt streaminggreb, men der bør være mindst en cooldown/status, evt. moderator-only mode eller command allowlist før bredere brug. Det er ikke nødvendigvis V1, men det er en realistisk live-risiko.

## Kode og arkitektur

### Overordnet

Arkitekturen matcher ret godt intentionen i `README.md`: `Audio/`, `Visuals/`, `Renderer/`, `UI/` og `App/` er lette at orientere sig i. `AppModel` samler dog meget ansvar, især audio status polling, display handling, Twitch lifecycle, persistence og view state. Det er acceptabelt i en lille V1, men de mest risikable dele bør skilles ud eller gøres mere testbare.

### Kritiske kodefund

1. Sentry-konfiguration ligger i delt scheme og har typo.
   I `echolume.xcodeproj/xcshareddata/xcschemes/echolume.xcscheme` ligger en Sentry ingest URL i `EnvironmentVariables`, men key hedder `SENTRY_DNS`. Appen læser `SENTRY_DSN` i `echolume/App/EcholumeApp.swift`. Fjern værdien fra shared scheme, roter DSN hvis den er reel, og brug `Sentry.xcconfig` eller lokal scheme config. Undgå at skrive selve URL'en i docs eller commits.

2. `AudioManager` har race conditions mellem main thread og audio queue.
   Eksempler:
   - `AppModel` læser `audioManager.engineRunning`, `lastError`, `formatSampleRate` og `formatChannelCount` i timeren (`echolume/App/AppModel.swift` linje 115-126).
   - `AudioManager` skriver samme state fra `audioManagerQueue` i `startEngine` (`echolume/Audio/AudioManager.swift` linje 120-247).
   - `selectedChannelPairIndex` skrives fra main og læses under engine start (`echolume/Audio/AudioManager.swift` linje 68, 177, 314-315).
   Lav et `AudioManagerState` snapshot under lock/queue, eller publicer stateændringer tilbage til main via Combine/AsyncStream.

3. Audio tap bruger lock på realtime path.
   `installTap`-callbacken tager `ringLock` og skriver samples (`echolume/Audio/AudioManager.swift` linje 182-219), mens `runFFT()` også tager `ringLock` og kopierer 2048 samples (`linje 262-280`). Hvis FFT-queue holder locken, kan audio callbacken blokere. For realtime audio bør callbacken hellere droppe work end vente.

4. Twitch reconnecter ved indtastning.
   `setTwitchChannel(_:)` kalder `connectTwitch()` hver gang bindingen ændres, hvis Twitch er enabled og teksten ikke er tom (`echolume/App/AppModel.swift` linje 510-518). `TextField` i `SetupView` opdaterer bindingen per tastetryk. Løsning: hold `draftTwitchChannel`, reconnect kun på submit/Connect, eller debounce og guard på "same channel".

5. Twitch subscriptions kan ophobes.
   `connectTwitch()` opretter en ny `TwitchChatManager` og gemmer en ny `$status` subscription i den fælles `cancellables` set (`echolume/App/AppModel.swift` linje 520-530). Når der reconnectes ofte, bliver gamle subscriptions ikke tydeligt annulleret. Brug en separat `twitchStatusCancellable`, ryd den ved disconnect, og undgå reconnect hvis channel ikke har ændret sig.

6. Renderer-fejl bliver til blank skærm.
   `MetalView` laver `MTLCreateSystemDefaultDevice()` og forsøger lazy renderer init, men der er ingen brugerstatus hvis device/pipeline/library fejler (`echolume/Renderer/MetalView.swift` linje 12-49). For en live-app bør renderer init failure ende i en synlig fejltilstand i setup/live overlay.

7. Swift/Metal uniform layout er manuel og uden test.
   `ShaderUniforms` i Swift skal matche `Uniforms` i Metal (`echolume/Renderer/Renderer.swift` linje 11-47 og `echolume/Renderer/Shaders.metal` linje 9-44). Tilføj en test eller en shared header/generator, så ændringer ikke giver skjulte shader-bugs.

8. Theme-kontrakten er kun delvist implementeret.
   README beskriver themes som palette + motion style + trail style. I koden bruges theme primært til palette; `Theme.baseSpeed` og `rotationSpeed` påvirker ikke `ParamMapping`, og `trailPersistence` sendes til shaderen, men bruges ikke i shaderen. Enten implementer det eller fjern/omformuler kontrakten.

9. Shape styles er ikke alle reelt forskellige.
   `shapeCircles` kalder blot `shapeBlobs` med justeret count, og `shapeGrid` er markeret som stub (`echolume/Renderer/Shaders.metal` linje 126-137). Hvis Shape er en central UI-kontrol, bør hver option have en tydelig visuel forskel.

10. Persistence matcher ikke README.
    README lover persistence af input device, channel pair, theme, abstraction og seed (`README.md` linje 223-227). Koden persisterer shape, scene, motion, noise, glitch, display og Twitch, men ikke device, channel pair, theme index, abstraction, energy bias eller seed. Det vil føles som tabt setup for live-brugere.

11. `SetupView` er blevet stor.
    `echolume/UI/SetupView.swift` er ca. 575 linjer og rummer input, output, style, performance, Twitch, bottom bar, permission og debug. Split den i små private views/filer, især `InputOutputSection`, `StyleSection`, `PerformanceSection`, `TwitchSection`, `DebugSection`.

12. CoreAudio listener return values ignoreres.
    `AudioObjectAddPropertyListenerBlock` kaldes uden at tjekke OSStatus (`echolume/App/AppModel.swift` linje 177-180). Log fejl i DEBUG og vis evt. manuel refresh/retry hvis listener ikke kan registreres.

13. Swift-version og project settings er uklare.
    README viser Swift 5.9+ badge, mens Xcode project har `SWIFT_VERSION = 5.0` og samtidig bruger nyere upcoming features/default actor isolation (`echolume.xcodeproj/project.pbxproj` linje 452-456 og 502-506). Sæt en bevidst Swift language mode og dokumenter Xcode/SDK-krav.

## Tests og kvalitetskontrol

### Nuværende status

- Der er gode unit tests for `TwitchChatManager.parseCommand`.
- UI tests er stadig Xcode-template/launch-test og validerer ikke centrale flows.
- CI kører kun `-only-testing:echolumeTests`, så UI tests indgår ikke i GitHub Actions.
- Lokal `xcodebuild` kunne ikke gennemføres i dette miljø, fordi Xcode mangler Metal Toolchain-komponenten (`xcodebuild -downloadComponent MetalToolchain`). Seneste GitHub Actions-run `25212082843` var dog grønt på både Build og Test 2026-05-01 11:05 UTC.

### Anbefalede tests

1. `FFT` og `magnitudeSpectrumToBands`
   Test med syntetiske sinustoner på fx 80 Hz, 1 kHz og 8 kHz, så low/mid/high band mapping ikke regress'er.

2. `ParamMapping`
   Test clamp ranges, impulse decay, glitch trigger bounds, theme palette fallback og at motion/noise/glitch påvirker forventede outputfelter.

3. `VisualParamsProvider`
   Test at updates clamped korrekt, reset-transient kun forbruges en gang, og at `hasSignal = false` nulstiller impact/impulse.

4. Randomize og persistence
   Test at den valgte Randomize-kontrakt faktisk sker, og at dokumenterede settings overlever restart via `UserDefaults`.

5. Shader uniform layout
   Minimum: test `MemoryLayout<ShaderUniforms>.stride` og offset-lignende forventninger. Bedre: generer en fælles C/Metal header.

6. Twitch lifecycle
   Gør WebSocket/session injicerbar, så connect/reconnect/rate-limit kan testes uden live Twitch.

7. UI smoke flows
   Tilføj mindst én UI test eller manuel test script for launch, permission-denied state, Ready/Back, Randomize og Twitch toggle. Hvis UI tests er for ustabile i CI, hold dem i en separat manuel workflow.

## Dokumentation

### Det stærke

- README er usædvanligt informativ for et lille app-projekt.
- `CONTRIBUTING.md`, `SECURITY.md`, MIT-license, PR template og issue templates er på plads.
- Marketing-sitet har relevante sider: how-it-works, OBS, Twitch, privacy og support.
- `docs/og-image.png` findes og er korrekt 1200x630.

### Anbefalinger

1. Opdater domain metadata.
   `docs/CNAME` og GitHub Pages bruger `echolume.iamjarl.com`, men canonical, Open Graph, sitemap, robots, issue template contact links og README-eksempler bruger `https://JarlLyng.github.io/echolume/`. Opdater dem samlet for at undgå SEO-split og forkerte delingspreview.

2. Opdater `SEO_STRATEGY.md`.
   Dokumentet siger stadig, at `docs/og-image.png` mangler. Filen findes nu. Det samme dokument bør også ændres fra GitHub Pages-subpath til custom domain.

3. Ret README/CONTRIBUTING mapper.
   `CONTRIBUTING.md` peger på `echolume/Rendering/` og `echolume/Themes/`, men repoet bruger `echolume/Renderer/` og `echolume/Visuals/`. Det er små ting, men de skaber friktion for nye contributors.

4. Skriv "current status" adskilt fra "target architecture".
   README blander delvist implementeret, ønsket og fremtidigt. Tilføj fx en kort "Implemented now" og "Planned" sektion, især for trails, randomize, persistence, themes og Sentry.

5. Tilføj screenshots eller en kort demo GIF/video.
   For en visual-app er tekst ikke nok. README og forsiden bør vise et faktisk visuelt output og setup-skærmen.

6. Gør privacy policy mere præcis.
   Den siger både Sentry performance monitoring og "no tracking". Det kan godt være foreneligt, men skriv mere præcist: hvilke events, hvornår Sentry er enabled, hvordan brugeren kan undgå det, og om release-builds har DSN.

7. Dokumenter lokal build-forudsætning.
   Hvis den valgte Xcode-installation kræver Metal Toolchain download i nogle miljøer, så tilføj troubleshooting: `xcodebuild -downloadComponent MetalToolchain`.

## GitHub-opsætning

### Observeret status

- Repo: `JarlLyng/echolume`.
- Visibility: private.
- Default branch: `main`.
- Description: tom.
- Homepage URL: tom.
- Issues: enabled.
- Projects: enabled.
- Wiki: enabled.
- License: MIT.
- Releases: ingen releases.
- GitHub Pages: public, custom domain `https://echolume.iamjarl.com/`, HTTPS enforced, legacy source `main` + `/docs`.
- Seneste `Build and Test` workflow på `main`: success.
- `main` branch protection: ikke aktiveret.
- Dependabot alerts: ikke aktiveret.
- Code scanning: ikke aktiveret.

### Anbefalinger

1. Sæt repo metadata.
   Tilføj description, homepage `https://echolume.iamjarl.com/`, topics som `macos`, `swift`, `metal`, `audio-visualizer`, `coreaudio`, `twitch`, `obs`.

2. Beskyt `main`.
   Kræv pull request før merge, kræv seneste `Build and Test`, kræv branch up to date eller merge queue, dismiss stale approvals, og lås force pushes/deletions.

3. Stram Actions workflow.
   I `.github/workflows/build.yml`:
   - Tilføj `permissions: contents: read`.
   - Tilføj `concurrency` pr. branch/ref med cancel-in-progress.
   - Tilføj `set -o pipefail` før `xcodebuild | xcpretty`.
   - Overvej at gemme result bundles eller `.xcresult` ved fejl.
   - Overvej at pinne eller dokumentere Xcode-versionen mere robust end hard-coded `/Applications/Xcode_16.app`.

4. Aktiver dependency-overvågning.
   Tilføj `.github/dependabot.yml` for `github-actions` og Swift Package Manager. Aktiver Dependabot alerts i repo settings.

5. Aktiver code scanning og secret scanning.
   Start simpelt med CodeQL hvis Swift-understøttelsen passer, ellers brug en lightere secret scanning/pre-commit strategi. Det vigtigste lige nu er at undgå flere shared secrets/config URLs i Xcode project/schemes.

6. Beslut hvad Wiki og Projects skal bruges til.
   Hvis de ikke bruges, slå dem fra. Et lille repo virker mere professionelt med færre tomme overflader.

7. Tilføj release workflow.
   Der er ingen GitHub releases, men marketing-sitet linker til releases. Tilføj en manuel workflow/checklist for version bump, archive, signing/notarization, zipped app/DMG, checksums og release notes. Hvis distribution først bliver App Store, så skriv det tydeligt og lad GitHub Releases være sekundært eller skjult.

8. Tilføj Pages-validering.
   Fordi Pages er public og deployer fra `main/docs`, bør PRs validere HTML-links, canonical domain, sitemap og evt. at `docs/CNAME` matcher repo Pages-indstillingen.

## Forslag til næste arbejdsordre

Hvis jeg skulle prioritere næste tekniske sprint, ville jeg gøre det i denne rækkefølge:

1. Sikkerhed/ops: fjern Sentry URL fra shared scheme, ret DSN-konfiguration, roter DSN hvis relevant, beskyt `main`, aktiver Dependabot/code scanning.
2. Stabilitet: refaktor `AudioManager` state til et trådsikkert snapshot og fjern blocking lock fra audio tap.
3. Twitch: adskil channel draft fra aktiv channel, undgå reconnect på hvert tastetryk, og ryd subscriptions korrekt.
4. Kontrakter: ret Randomize, persistence og theme/motion/trail-adfærd så kode og README stemmer.
5. Testpakke: tilføj tests for FFT, ParamMapping, persistence og uniform layout.
6. Docs/web: opdater custom domain overalt, ret SEO_STRATEGY og tilføj screenshots/demo.
7. Release: lav sign/notarize/release checklist eller workflow.

## Verifikation udført

- Læst projektstruktur, centrale Swift/Metal-filer, tests, docs og `.github`.
- Tjekket `git status`: working tree var ren før anbefalingsfilen blev skrevet.
- Kørte lokal `xcodebuild ... build`; den fejlede i dette miljø på manglende Metal Toolchain, ikke på en identificeret Swift-fejl.
- Tjekket GitHub repo metadata via `gh repo view`.
- Tjekket branch protection via GitHub API: `main` er ikke protected.
- Tjekket seneste GitHub Actions-runs: seneste `Build and Test` var successful.
- Tjekket GitHub Pages API: custom domain og HTTPS er aktive.
- Tjekket Dependabot/code scanning endpoints: ikke aktiveret.
