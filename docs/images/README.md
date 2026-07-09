# Atmosphere images for the Echolume site

Drop image files here (repo path: `docs/images/`). They are served at
`https://echolume.iamjarl.com/images/<filename>`.

## Currently wired
- **`hero-bg.jpg`** — optional atmosphere image behind the hero. Landscape,
  dark/moody works best (there's a dark gradient overlay on top). Recommended
  ~2400×1400, JPEG, < ~300 KB. If absent, a gradient fallback shows — nothing
  breaks.

Add more slots by referencing new files from `styles.css` / `index.html`.
Keep files web-optimized (resize + compress) so page speed stays high.
