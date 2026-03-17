# SEO-strategi for Echolume

Dette dokument beskriver en SEO-strategi for Echolumes marketing-site på GitHub Pages (`https://JarlLyng.github.io/echolume/`). Projektet er en macOS-app til live, lydreaktive 2D-visuals med Metal, målrettet streaming (OBS, Twitch) og performance.

---

## 1. Nuværende status

### Det der allerede fungerer godt

- **Canonical URLs** på alle sider — reducerer duplikatindeksering.
- **Meta descriptions** på alle sider — unikke og relevante (ca. 150–160 tegn).
- **Open Graph og Twitter Cards** på de fleste sider — bedre deling på sociale medier.
- **Struktureret data:** `SoftwareApplication` (JSON-LD) på forsiden og `FAQPage` på support — understøtter rich results i søgninger.
- **robots.txt** med tilladelse til alle og reference til sitemap.
- **sitemap.xml** med alle vigtige sider og fornuftige prioriteter.
- **Semantisk HTML** med én `<h1>` per side, logiske `<section>` og `<article>`.
- **Mobile viewport** og **theme-color** sat.

### Identificerede huller

| Problem | Detalje |
|--------|--------|
| **Manglende OG-billede** | `og-image.png` refereres i HTML men findes ikke i `docs/`. Uden billede falder klik fra deling. |
| **Sprog-uensartethed** | Forside, How it works, Support og Privacy er på engelsk; OBS- og Twitch-guides er på dansk (`lang="da"` + brødtekst). Søgemaskiner og brugere får blandet sprogsignal. |
| **Support og Privacy** | Mangler `og:image` og (på privacy) `twitter:card`. |
| **Sitemap** | Ingen `lastmod` eller `changefreq` — mindre vigtigt, men nyttigt for genindeksering. |
| **Ingen hreflang** | Hvis både engelsk og dansk skal understøttes, bør sprogversioner markeres med `hreflang`. |
| **Forside-canonical** | Canonical er `https://.../echolume/` (med slash), men interne links bruger `index.html` — konsistens er bedre for brugeroplevelse og evt. redirects. |

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

- Behold nuværende URL-liste og prioriteter.
- **Tilføj** `lastmod` (ISO 8601) for hver URL, opdater ved ændringer.
- Valgfrit: `changefreq` (f.eks. `weekly` for forsiden, `monthly` for privacy).

Eksempel:

```xml
<url>
  <loc>https://JarlLyng.github.io/echolume/</loc>
  <lastmod>2025-03-17</lastmod>
  <changefreq>weekly</changefreq>
  <priority>1.0</priority>
</url>
```

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

### Anbefalede udvidelser

- **BreadcrumbList** på undersider: Forside → How it works / OBS Guide / Twitch / Support / Privacy. Giver breadcrumb-rich results i Google.
- **HowTo** på how-it-works, obs-guide og twitch-guide: step-by-step giver mulighed for HowTo-snippets i søgninger.
- **Article** på guide-sider: `datePublished` / `dateModified` og `author` styrker indholds-freshness og tillid.

Disse kan tilføjes som ekstra `application/ld+json`-blokke i `<head>` uden at ændre det eksisterende indhold.

---

## 6. Social deling og OG-billede

### 6.1 OG-billede (påkrævet)

- **Fil:** Opret `docs/og-image.png`.
- **Anbefalet størrelse:** 1200×630 px (Open Graph standard).
- **Indhold:** App-navn (Echolume), tagline ("Sound into light") og evt. et stilbillede fra appen (uden for meget tekst).
- Alle sider der har `og:image` peger i dag på `https://JarlLyng.github.io/echolume/og-image.png` — sørg for at filen ligger i `docs/` så den serveres korrekt.

### 6.2 Udfyld manglende sociale meta

- **support.html** og **privacy.html:** Tilføj `og:image` og `twitter:card` (summary_large_image) som på de øvrige sider, så delinger ser ens og professionelle ud.

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
| **P0** | Opret og tilføj `docs/og-image.png` (1200×630). | Social deling og konsistens; undgår 404 på refereret billede. |
| **P0** | Tilføj `og:image` + `twitter:card` på support.html og privacy.html. | Ens delingsoplevelse på tværs af sider. |
| **P1** | Beslut sprogstrategi: enten oversæt OBS/Twitch-guides til engelsk (anbefalet) eller tilføj hreflang og dobbeltsproget indhold. | Klart sprogsignal for Google og brugerne. |
| **P1** | Tilføj `lastmod` (og evt. `changefreq`) i sitemap.xml; opdater ved ændringer. | Bedre signal til genindeksering. |
| **P2** | Overvej stærkere keyword i forsidens title/meta (f.eks. "Live Audio-Reactive Visuals for macOS"). | Bedre match på "audio reactive visuals mac". |
| **P2** | Tilføj BreadcrumbList (JSON-LD) på undersider. | Mulighed for breadcrumb-rich results. |
| **P3** | Tilføj HowTo-schema på how-it-works, obs-guide og twitch-guide. | Mulighed for HowTo-snippets. |
| **P3** | Kort intern link fra how-it-works til twitch-guide (og evt. omvendt) hvor det giver mening. | Styrker indeksering og brugerflow. |

---

## 10. Kort opsummering

- **Stærke sider:** Canonical, meta, grundlæggende strukturerede data, sitemap, robots.txt og semantisk HTML.
- **Vigtigste huller:** Manglende `og-image.png`, sprog-uensartethed (EN/DA), manglende sociale meta på support/privacy, og mulighed for at styrke sitemap og schema (breadcrumbs, HowTo).
- **Anbefaling:** Få på plads P0 og P1 (billede, sociale meta, sprogstrategi, sitemap), derefter P2/P3 for bedre rich results og søgeord. Hold titler og beskrivelser tæt på de anbefalede søgeord uden at overoptimere.

---

*Dokumentet er udarbejdet ud fra gennemgang af `docs/` (HTML, sitemap, robots.txt) og README. Opdater strategien ved store ændringer i indhold eller målgruppe.*
