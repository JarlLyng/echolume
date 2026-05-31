# SEO-strategi for Echolume

Dette dokument beskriver en SEO-strategi for Echolumes marketing-site på GitHub Pages (`https://echolume.iamjarl.com/`). Projektet er en macOS-app til live, lydreaktive 2D-visuals med Metal, målrettet streaming (OBS, Twitch) og performance.

---

## 1. Nuværende status

### På plads

- **Canonical URLs**, **meta descriptions**, **Open Graph**, **Twitter Cards** (`summary_large_image`) på alle sider.
- **Struktureret data:** `SoftwareApplication` på forsiden; `HowTo` + `FAQPage` + `BreadcrumbList` på guide-siderne (how-it-works, obs-guide, twitch-guide); `FAQPage` + `BreadcrumbList` på support; `BreadcrumbList` på privacy.
- **robots.txt**, **sitemap.xml** med `lastmod` og `changefreq` per URL.
- **Semantisk HTML**, **viewport**, **theme-color**.
- **Sprog ensartet:** alle sider er nu engelske (`lang="en"`).
- **URL-konsistens:** interne links peger på roden (`/`) i overensstemmelse med canonical.
- **Privatlivsvenlig analytics:** Umami (cookieless) på alle sider.

### Huller / forbedringer

| Problem | Detalje |
|--------|--------|
| **OG-billede skal optimeres** | `og-image.png` ligger nu i `docs/`, men er ~880 KB og 1024×1024 (JPEG). Bør re-eksporteres til 1200×630 og <150 KB. Spores i issue [#62](https://github.com/JarlLyng/echolume/issues/62). |
| **Ingen hreflang** | Ikke relevant så længe sitet er ét sprog (engelsk); kun nødvendigt hvis der senere tilføjes dansk parallel-indhold. |
| **`Article`-schema mangler** | `datePublished`/`dateModified` på guide-siderne ville styrke freshness (se §5). |

---

## 2. Målgruppe og søgeord

### Primær målgruppe

- Mac-brugere der laver **live visuals** til streaming (Twitch, YouTube) eller performance.
- Brugere der søger **OBS + audio visuals**, **BlackHole + streaming**, **Twitch chat commands** til visuals.
- Udviklere og nørder der søger **audio reactive visuals macOS**, **Metal 2D visuals**, **low latency VJ app**.

### Anbefalede søgeord (prioriteret)

**Brand / produkt:**
- Echolume
- Echolume macOS
- Echolume OBS / Echolume Twitch

**Generelle (eng.):**
- audio reactive visuals mac
- live visuals macOS
- OBS audio reactive visuals
- BlackHole OBS setup
- Twitch stream visuals
- VJ app Mac
- audio to visuals app

**Guides / how-to:**
- how to use BlackHole with OBS
- route OBS audio to another app
- Twitch chat commands for stream overlays

**Tekniske:**
- Metal 2D rendering macOS
- CoreAudio input device Mac app

Strategien bør sikre, at titler, meta descriptions og overskrifter indeholder disse begreber naturligt, især på forsiden og guide-siderne.

---

## 3. Teknisk SEO

### 3.1 Sitemap

- `sitemap.xml` har allerede `lastmod` og `changefreq` — **opdater `lastmod`** (ISO 8601-dato) når indhold på en given URL ændres, så crawlers får et friskhedssignal.

### 3.2 Canonical og URL-konsistens

- Forside: Overvej at bruge samme format overalt (enten altid `index.html` eller altid `/` i canonicals og interne links), så bruger- og crawler-oplevelsen er ens.
- Hvis GitHub Pages serverer både `/` og `/index.html`, er én canonical (som nu) fint; sørg for at interne links ikke skifter mellem de to uden grund.

### 3.3 robots.txt

Nuværende indhold er passende. Ingen ændringer nødvendige med mindre I tilføjer områder der ikke skal indekseres.

---

## 4. On-page SEO

### 4.1 Titler (title)

- **Forside:** Behold "Echolume — Sound into light" eller tilpas til "Echolume — Live Audio-Reactive Visuals for macOS" for stærkere søgeord.
- **Undersider:** Struktur "Specifikt emne — Echolume" er god; behold den.
- Sigte efter **ca. 50–60 tegn** og inkluder brand + ét hovedkeyword per side.

### 4.2 Meta description

- **Længde:** 150–160 tegn.
- **Indhold:** Unik per side, med call-to-action eller konkret værdi og ét relevant søgeord.
- Nuværende beskrivelser er allerede gode; ved opdateringer, inkluder f.eks. "OBS", "Twitch", "BlackHole", "macOS" hvor det giver mening.

### 4.3 Overskrifter (H1, H2)

- Én H1 per side (allerede implementeret).
- Brug H2 til sektioner; hold kort og søgeordsvenlige uden at fylde (f.eks. "OBS Studio setup", "Twitch chat commands").

### 4.4 Sprogstrategi

To muligheder:

**A) Ét hovedsprog (anbefalet for start)**  
- Vælg enten **engelsk** eller **dansk** for hele sitet.
- Engelsk giver bredest reach (OBS, Twitch, macOS-communities er ofte engelsksprogede).
- Hvis I vælger engelsk: oversæt OBS- og Twitch-guides til engelsk og sæt `lang="en"` på alle sider.

**B) To sprog med hreflang**  
- Behold både engelske og danske sider.
- Tilføj `<link rel="alternate" hreflang="en" href="...">` / `hreflang="da" href="...">` i `<head>` på alle sider, plus `hreflang="x-default"` (typisk engelsk).
- Kræver enten separate filer (f.eks. `obs-guide.html` og `obs-guide-da.html`) eller et lille build-step der genererer hreflang.

Anbefaling: Start med **A) fuld engelsk** for bedre international søgeeffekt, medmindre målgruppen primært er dansk.

---

## 5. Struktureret data (Schema.org)

### Allerede implementeret

- **SoftwareApplication** på forsiden: navn, OS, kategori, beskrivelse, pris, URL, forfatter.
- **HowTo** på how-it-works, obs-guide og twitch-guide.
- **FAQPage** på support og på alle tre guide-sider (spejler on-page-FAQ).
- **BreadcrumbList** på alle nuværende undersider (how-it-works, obs-guide, twitch-guide, support, privacy).

### Anbefalede udvidelser

- **Article** på guide-sider: `datePublished` / `dateModified` og `author` styrker indholds-freshness og tillid.

Tilføj som ekstra `application/ld+json`-blokke i `<head>` uden at fjerne eksisterende schema.

---

## 6. Social deling og OG-billede

### 6.1 OG-billede (skal optimeres)

- **Fil:** `docs/og-image.png` findes nu og serveres korrekt.
- **Problem:** den er ~880 KB og 1024×1024 (JPEG-data). Open Graph-standarden er **1200×630 px**, og kvadratiske billeder beskæres/letterboxes i Twitter/Facebook/Slack/iMessage.
- **Handling:** re-eksportér til 1200×630 og komprimér til <150 KB. Spores i issue [#62](https://github.com/JarlLyng/echolume/issues/62).
- **Indhold:** App-navn (Echolume), tagline ("Sound into light") og evt. et stilbillede fra appen (uden for meget tekst).

### 6.2 Sociale meta på alle sider

- **På plads** på support og privacy. Når `og-image.png` tilføjes, valideres delingspreview på tværs af sider.

---

## 7. Indhold og interne links

### 7.1 Indre linking

- Footer og nav er allerede gode med links til alle vigtige sider.
- På forsiden: "How it works" og download-CTA er tydelige.
- **Anbefaling:** På how-it-works nævnes allerede OBS; tilføj et kort afsnit eller et link til "Twitch integration" med link til twitch-guide.html, så OBS- og Twitch-siderne understøtter hinanden (og fanger flere long-tail søgninger).

### 7.2 Indhold der styrker SEO

- **Blog eller "Resources"-sektion** er uden for nuværende scope, men på sigt kan korte artikler som "How to get audio-reactive visuals in OBS on Mac" eller "Twitch chat commands for streamers" give ekstra trafik og interne links.
- Korte **FAQ-udvidelser** på support (f.eks. "Does Echolume work with BlackHole?") med naturlige søgeord understøtter både FAQPage-schema og brugerbehov.

---

## 8. App Store og fremtid

- Når Echolume kommer på **Mac App Store**, opdater forsidens download-sektion med App Store-link og behold GitHub Releases som sekundær kilde.
- **Support-URL** og **Privacy-URL** fra denne side bør bruges i App Store Connect — de er allerede SEO- og bruger-venlige.
- Overvej at tilføje en **dedikeret "Download"-side** med titel/description rettet mod "download Echolume", "Echolume Mac App Store", når det er relevant.

---

## 9. Handlingsplan (prioriteret)

| Prioritet | Handling | Effekt |
|-----------|----------|--------|
| **P1** | Optimér `docs/og-image.png` til 1200×630 / <150 KB ([#62](https://github.com/JarlLyng/echolume/issues/62)). | Korrekt, let delingspreview. |
| **P1** | Opdater `lastmod` i `sitemap.xml` når sider ændres (fx ved denne type release). | Friskhedssignal til crawlers. |
| **P2** | Stærkere keyword i forsidens title/meta (f.eks. "Live Audio-Reactive Visuals for macOS"). | Bedre match på generiske søgninger. |
| **P3** | `Article`-schema (`datePublished`/`dateModified`) på guide-siderne. | Freshness-signal. |
| **P3** | Krydslinks mellem how-it-works ↔ twitch-guide/obs-guide hvor det giver mening. | Intern linking og brugerflow. |
| ✅ Gjort | Sprog ensartet (engelsk + `lang="en"` overalt); HowTo + FAQPage på guides; interne links → `/`; død CSS fjernet. | — |

---

## 10. Kort opsummering

- **Stærkt:** Teknisk SEO-basis (canonical, meta, OG/Twitter, sitemap med lastmod, schema inkl. SoftwareApplication, HowTo, FAQPage og breadcrumbs); ensartet engelsk; konsistente interne links.
- **Største hul:** `og-image.png` skal optimeres (størrelse/format — [#62](https://github.com/JarlLyng/echolume/issues/62)).
- **Næste skridt:** optimér OG-billede + vedligehold `lastmod` ved indholdsændringer.

---

*Opdater dette dokument når `docs/`-indhold eller SEO-mål ændres væsentligt.*
