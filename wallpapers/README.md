# Archived wallpaper previews

The active configuration selects the top-level `wallpaper` link, which points
to `wallpapers/wallpaper`. That inner link currently selects the first preview;
change it to any SVG below to try another version.

- `01-braille-mask-katakana.svg` — the last OpenCode version you liked:
  Braille Ganesha mask with katakana/digit Matrix rain clipped inside.
- `02-braille-direct.svg` — direct Braille rendering with a faint full-screen
  Matrix texture.
- `03-matrix-mosaic.svg` — the converted `ganesha-matrix.txt` character
  mosaic that replaced Braille cells with Matrix characters.
- `04-glpaper-matrix.glsl` — the live shader experiment. It needs glpaper and
  is not used by Sway.

Current link:

```text
wallpaper -> wallpapers/wallpaper -> 01-braille-mask-katakana.svg
```

To preview an SVG temporarily in Sway:

```sh
swaymsg 'output * bg /home/lg/.config/nix/wallpapers/01-braille-mask-katakana.svg fill'
```

Reloading Sway or rebuilding the configuration restores the active wallpaper.
