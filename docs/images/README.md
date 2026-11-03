# Atmosphere images for the Echolume site

Drop image files here (repo path: `docs/images/`). They are served at
`https://echolume.iamjarl.com/images/<filename>`.

## Currently wired
- The hero section layers a live canvas simulation (see the hero script in
  `index.html`) over a static poster image, `hero-poster.jpg`, set as the
  `.hero` background in `styles.css`. The poster shows before the canvas paints
  and on reduced-motion.

Add more slots by referencing new files from `styles.css` / `index.html`.
Keep files web-optimized (resize + compress) so page speed stays high.

## Photo credits (Unsplash — free license, commercial use)
- Club/crowd scenes: Aleksandr Popov, Baptiste Merel, Pim Myten (Unsplash).
Web-optimised copies live here; full-res sources are in `design/photos/`.
