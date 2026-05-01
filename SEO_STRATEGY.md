# SEO-strategi for Echolume

Dette dokument beskriver en SEO-strategi for Echolumes marketing-site på GitHub Pages (`https://echolume.iamjarl.com/`). Projektet er en macOS-app til live, lydreaktive 2D-visuals med Metal, målrettet streaming (OBS, Twitch) og performance.

---

## 1. Nuværende status

### På plads

- **Canonical URLs**, **meta descriptions**, **Open Graph**, **Twitter Cards** (`summary_large_image`) på alle sider.
- **Struktureret data:** `SoftwareApplication` + `FAQPage` på support; **BreadcrumbList** på bl.a. support og privacy.
- **robots.txt**, **sitemap.xml** med `lastmod` og `changefreq` per URL.
- **Semantisk HTML**, **viewport**, **theme-color**.

### Huller / forbedringer

| Problem | Detalje |
|--------|--------|
| **Manglende OG-billede** | `og-image.png` refereres i HTML men ligger ikke i `docs/` — deling viser 404/blankt billede. |
| **Sprog-uensartethed** | De fleste sider er engelske; OBS- og Twitch-guides er danske (`lang="da"`). Blandet sprogsignal for SEO og brugere. |
| **Ingen hreflang** | Kun relevant hvis I bevidst kører to sprog; ellers ensret sprog på tværs af sider. |
| **URL-konsistens** | Canonical bruger ofte trailing slash på roden; nogle interne links peger på `index.html` — ensret hvis I vil minimere dubletter i analytics. |

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
- **FAQPage** på support med relevante Q&A.
- **BreadcrumbList** på alle nuværende undersider (how-it-works, obs-guide, twitch-guide, support, privacy).

### Anbefalede udvidelser

- **HowTo** på how-it-works, obs-guide og twitch-guide: step-by-step giver mulighed for HowTo-snippets i søgninger.
- **Article** på guide-sider: `datePublished` / `dateModified` og `author` styrker indholds-freshness og tillid.

Tilføj som ekstra `application/ld+json`-blokke i `<head>` uden at fjerne eksisterende schema.

---

## 6. Social deling og OG-billede

### 6.1 OG-billede (påkrævet)

- **Fil:** Opret `docs/og-image.png`.
- **Anbefalet størrelse:** 1200×630 px (Open Graph standard).
- **Indhold:** App-navn (Echolume), tagline ("Sound into light") og evt. et stilbillede fra appen (uden for meget tekst).
- Alle sider der har `og:image` peger i dag på `https://echolume.iamjarl.com/og-image.png` — sørg for at filen ligger i `docs/` så den serveres korrekt.

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
| **P0** | Opret og commit `docs/og-image.png` (1200×630). | Korrekt delingspreview; ingen død `og:image`-URL. |
| **P1** | Beslut sprogstrategi: oversæt OBS/Twitch-guides til engelsk *eller* hreflang + parallel indhold. | Klart sprogsignal. |
| **P1** | Opdater `lastmod` i `sitemap.xml` når sider ændres (fx ved denne type release). | Friskhedssignal til crawlers. |
| **P2** | Stærkere keyword i forsidens title/meta (f.eks. "Live Audio-Reactive Visuals for macOS"). | Bedre match på generiske søgninger. |
| **P2** | BreadcrumbList på *alle* undersider der mangler det (hvis nogen). | Breadcrumb rich results. |
| **P3** | HowTo-schema på how-it-works, obs-guide og twitch-guide. | HowTo-snippets i søgning. |
| **P3** | Krydslinks mellem how-it-works ↔ twitch-guide/obs-guide hvor det giver mening. | Intern linking og brugerflow. |

---

## 10. Kort opsummering

- **Stærkt:** Teknisk SEO-basis (canonical, meta, OG/Twitter, sitemap med lastmod, schema inkl. FAQ og breadcrumbs på flere sider).
- **Største hul:** Fysisk `og-image.png` mangler stadig i repo trods referencer i HTML.
- **Næste skridt:** P0 (billede) + P1 (sprog + vedligehold `lastmod`).

---

*Opdater dette dokument når `docs/`-indhold eller SEO-mål ændres væsentligt.*
