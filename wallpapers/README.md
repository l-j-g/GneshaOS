# Archived wallpaper previews

Home Manager seeds these previews into `~/wallpapers` on rebuild. The active
wallpaper is the mutable file `~/wallpapers/wallpaper`; it is seeded from the
preferred Braille-mask preview only when that file does not already exist.

- `01-matrix-glow.svg` — the oldest OpenCode version: a quiet Matrix rain
  field with phosphor glow and the “wake up, Neo...” caption.
- `02-braille-direct.svg` — direct Braille rendering with a faint full-screen
  Matrix texture.
- `03-braille-mask-katakana.svg` — the preferred OpenCode version:
  Braille Ganesha mask with katakana/digit Matrix rain clipped inside.
- `sources/ganesha-matrix.txt` — the source character used by the converted
  `04-matrix-mosaic.svg` artwork.
- `04-matrix-mosaic.svg` — the converted character mosaic from
  `sources/ganesha-matrix.txt`, replacing Braille cells with Matrix
  characters.
- `sources/ganesha-braille.txt` — the source Braille character used by the
  Braille previews.
- `05-glpaper-matrix.glsl` — the live shader experiment. It needs glpaper and
  is not used by Sway.

To change it to any image:

```sh
cp /path/to/xyz.jpg ~/wallpapers/wallpaper
swaymsg reload
```

To preview an SVG temporarily in Sway:

```sh
swaymsg 'output * bg /home/lg/wallpapers/wallpaper fill'
```

Rebuilding only creates missing preview/default files; it preserves an existing
`~/wallpapers/wallpaper`. Reload Sway after replacing it.
