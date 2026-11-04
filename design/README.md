# design/

Source and working assets for Echolume's App Store listing and marketing site.
None of this ships inside the app, and most of it is not referenced by the app
code. It lives here so the originals are versioned and reproducible.

## Contents

- `app-icon/` — icon PNG sources.
- `app-store/` — App Store assets:
  - `raw/` and `frames/` — raw captures and framed screenshots used to prepare
    store previews (see #163). Archival source, large.
  - `description.md` — the App Store description. The release flow pastes it into
    App Store Connect (see `RELEASE_CHECKLIST.md`).
- `photos/` — full-resolution Unsplash sources. Web-optimized copies that the
  site actually serves live in `docs/images/` (credits in
  `docs/images/README.md`).
- `social-card/` — source for the repo's social preview card, rendered per its
  own README and referenced by `RELEASE_CHECKLIST.md`.

## Note

The raw captures and photo sources are heavy and one-time. Prune them if the
originals are no longer needed, but the release flow depends on `social-card/`
and `app-store/description.md`, so keep those.
