# Social card

`social-card.html` is the source for `docs/social-card.jpg`, the 1200x630 image every page
declares as `og:image`. It uses the site's fonts (Outfit, Inter), the music family teal and
the real Spectrum Ring capture in `docs/images/hero-poster.jpg`.

Regenerate it whenever the price, the headline or the platform changes. The card states
"$19.99 once" and "Mac App Store", so it drifts the same way the rest of the public copy
does (see `RELEASE_CHECKLIST.md`).

```bash
cd design/social-card
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu \
  --hide-scrollbars --force-device-scale-factor=1 --window-size=1200,630 \
  --virtual-time-budget=10000 --screenshot="$PWD/social-card.png" "file://$PWD/social-card.html"
sips -s format jpeg -s formatOptions 88 social-card.png --out ../../docs/social-card.jpg
rm social-card.png
```

The virtual time budget gives the Google Fonts request time to finish; without it the card
renders in the fallback system font.

Platforms cache the image per URL. If you replace the card and want existing shares to
refresh sooner, give the file a new name and update the `og:image` tags on all six pages,
or re-scrape the URL in each platform's debugger.

Keep the copy inside `VOICE.md`: no em-dashes, pay-once framing.
