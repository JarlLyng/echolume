# Release checklist

Run this before submitting a version to App Store Connect.

It exists because the public facts drift quietly between releases. Real examples found
in one audit: the site's JSON-LD still declared `softwareVersion: 1.0.0` months after
1.3 was live, the store description advertised 7 scenes and 6 themes when the app had
10 of each, `README.md` still listed video recording as planned after it shipped in 1.2,
and `sitemap.xml` claimed May dates plus screenshots that were no longer on the page.
None of it was caught at release time, because nothing asked.

---

## 1. Public facts

Check every place the same fact appears, not just the one you remember.

- [ ] Scene and theme counts match the code (`echolume/Visuals/SceneType.swift`,
      `echolume/Visuals/ThemeLibrary.swift`) in **all three** places they appear: the
      App Store description, `docs/index.html` JSON-LD `featureList`, and `README.md`.
- [ ] `docs/index.html` JSON-LD `softwareVersion` and `releaseNotes` describe the
      version being shipped.
- [ ] `README.md`: nothing already shipped is still under **Planned**, and no note
      describes a fixed problem as open.
- [ ] `docs/sitemap.xml`: `lastmod` per page reflects a real edit to that page, and the
      `image:` entries list images actually on it.
- [ ] Features described on the site still behave as described. Two that are easy to get
      wrong: recording writes **video only, no audio track**, and the AUv3 plugin route
      needs **OSC input enabled** in Setup, because `oscEnabled` defaults to `false`.

## 2. Voice gate

Full rules in `VOICE.md` in the private strategy hub. This is a gate, not a cleanup.

- [ ] **No em-dashes** in public copy. Use a comma, a period or parentheses. A bullet
      label takes a colon: `Feature: explanation`.
- [ ] **No bullet lists** in public copy. App Store feature lists are the carve-out, and
      that carve-out covers lists, not punctuation.
- [ ] Pay-once framing: **$19.99 one-time, no subscription, no in-app purchases**. Never
      call it free.
- [ ] Minimal emojis, no AI-sounding phrasing.

Applies to the App Store description and What's New, the site, and any launch post.

> The App Store description is **version-locked**: it can only be edited alongside a
> version submission. Store copy fixes have to happen here, or they wait for the release
> after this one.

## 3. Version numbers

- [ ] Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` **together and across every
      target**: the app, the `EcholumeAudioTap` AUv3 plugin, and the test targets. The
      plugin must share both values with the app or ASC raises a validation warning.
- [ ] The new build number must be higher than the latest **approved or released** build
      across **all** marketing versions, not just the current one. Getting this wrong
      passes archive and export, then fails only at "Preparing build for App Store
      Connect".
- [ ] Xcode Cloud stamps its own build number and ignores `CURRENT_PROJECT_VERSION`. Set
      its **Next Build Number** above the released build (Xcode, Integrate, Manage Build
      Number) rather than expecting the project setting to win.
- [ ] `CHANGELOG.md` entry written and dated.

## 4. Ship

- [ ] Merge `main` into `release` and push.
- [ ] Start the build **manually**: Xcode Cloud, Start Build, `release`. The push
      auto-trigger has been unreliable.
- [ ] Watch progress in App Store Connect under Xcode Cloud. GitHub check-runs often show
      nothing for Cloud builds even when they succeed, so do not treat a missing check as
      a failure.

## 5. After it goes live

- [ ] Tag `vX.Y.Z` and create the GitHub release.
- [ ] Update the `PORTFOLIO` row in the private strategy hub.
- [ ] Note the build number that shipped. The next upload must exceed it.
