# Security Policy

## Supported Versions

Only the latest released version of Echolume receives security fixes.

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in Echolume, please **do not open a public GitHub issue.**

Instead, report it privately by:

1. Using GitHub's [private vulnerability reporting](https://github.com/JarlLyng/echolume/security/advisories/new) feature, or
2. Sending an email to the maintainer (see profile at [github.com/JarlLyng](https://github.com/JarlLyng))

Include:
- A description of the vulnerability
- Steps to reproduce
- The affected version
- Any potential impact

You should receive a response within 7 days. We aim to release a fix within 30 days for confirmed issues.

## Scope

Security reports are welcome for:
- The Echolume macOS app source code
- The Twitch IRC integration
- Audio/microphone permission handling
- The marketing site at `docs/`

Out of scope:
- Vulnerabilities in third-party dependencies (please report those upstream — Sentry, IAMJARLDesignTokens)
- Issues requiring physical access to the user's machine
- Social engineering attacks

## Disclosure Policy

We follow coordinated disclosure: once a fix is released, we will publish an advisory crediting the reporter (unless anonymity is requested).
