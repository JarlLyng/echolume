# AGENTS.md — Echolume

Quick-start context for developers and AI assistants. Architecture, milestones, and
development conventions live in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md); the feature
list lives in [`README.md`](README.md) — do not invent features beyond those two sources.

## What is Echolume?

A macOS app for live, audio-reactive 2D visuals rendered with Metal. A performance tool for
producers, VJs, and DJs: pick an audio input, pick a theme, hit Ready, and perform. Stable,
low-latency, minimal UI, beautiful results with few controls.

- **Developer:** Jarl / [IAMJARL](https://iamjarl.com)
- **Website:** [echolume.iamjarl.com](https://echolume.iamjarl.com)
- **License:** [MIT](LICENSE) — open source.
- **Price:** $19.99 USD one-time (no in-app purchases, no subscription, no ads). The
  portfolio's premium entry — never call it "free".
- **Status:** live on the Mac App Store (app id 6759684323). Launched Jul 2026; current shipped version **1.3.0**.
- **Requirements:** macOS 14+, Metal.

## Boundaries: work only in this repo

- Commit, push and open pull requests **only in this repo**. Never edit, commit to, push to or
  open a pull request in another IAMJARL repo, and that includes `iamjarl-design`.
- To ask another repo for something, **open an issue there**. Public repos get findings, never
  measured numbers. If it is strategic, or not safe in public, it goes to the hub instead.
- The one place outside this repo you write is this app's own folder in the private hub
  (`Echolume/`). Shared hub files (`PORTFOLIO.md`, the standards, `tools/`) are changed from inside
  the hub; if one needs changing, open an issue there.
- If a task seems to need a change in another repo, stop, open the issue, and carry on with what
  this repo can do.

## Strategy lives in the private hub

Target audience, positioning, pricing reasoning, SEO strategy, and launch plans are **not**
in this public repo — they're in the private
[iamjarl-strategy](https://github.com/JarlLyng/iamjarl-strategy) hub (folder `Echolume/`).
Before doing any audience, positioning, pricing, or marketing work, read that repo's
`CONVENTIONS.md` and write results there, not here.

## Voice (read before writing ANY public copy — this is a LAUNCH GATE)

Echolume launches after the portfolio's voice rules were set, so all launch copy (App Store
listing, site, launch posts) must comply from day one — this is a gate before release, not an
opportunistic cleanup. Follow `VOICE.md` in the private hub. Hard rules: no em-dashes, no
bullet lists in public copy, minimal emojis, avoid AI-sounding phrasing, pay-once framing
($19.99 once, no subscription). Echolume's own overlay is deliberately undefined until launch
signals arrive: write the base voice (honest maker, calm, concrete), and log audience
reactions in the hub so the overlay can grow from real replies.

## Before submitting a release

Run [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md). It gates the voice rules above and the
public facts that drift between versions (scene/theme counts, JSON-LD version, README
shipped-vs-planned, sitemap dates), plus the version-numbering rules that have broken
deliveries before. The App Store description is version-locked, so store copy can only be
fixed alongside a submission.

## What does NOT exist

Critical for anyone writing copy or answering questions about Echolume. These get
described as real features by assistants and reviewers who have not been told otherwise,
and that is how the site ended up with claims that had to be corrected (#177, #178).

- **The recorder writes silent video.** `Record`/`V` in Live produces an H.264 `.mp4` in
  `~/Movies` with **no audio track** (`echolume/Renderer/VideoRecorder.swift`). It does
  not export a finished music video with sound. This is the most common misread of the
  product.
- **No local audio file import.** You cannot load a track and render a music video from
  it. That is an idea under discussion (#182), not a feature.
- **No system-audio capture.** Echolume reads audio **inputs** only. System output has to
  be bridged in with a loopback device such as BlackHole, or come from the bundled AUv3
  plugin. Related idea: #183.
- **The AUv3 plugin alone is not enough.** `oscEnabled` defaults to `false`
  (`echolume/App/AppModel.swift`), so the DAW route needs OSC input switched on in Setup.
- **Twitch is anonymous read-only.** OAuth is not implemented (#4).
- **macOS only.** No Windows, iOS or iPadOS build, and none planned.

## Keep this file current

This file is the first thing an assistant reads, so a stale line here propagates into the
site, the README and the store listing before anyone notices. When the shipped version,
the price, the platform support or the list above changes, update it in the same commit.
`RELEASE_CHECKLIST.md` covers the public surfaces; this file is the one that is read
before any of them.
