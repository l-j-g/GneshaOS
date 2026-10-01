# Fonts and rendering profiles

Choose the actual family in `home/variables.nix`:

```nix
terminalFontFamily = "BlexMono Nerd Font Mono";
```

`home/fonts/default.nix` hands that choice to Fontconfig as the preferred
`monospace` family, followed by `Symbols Nerd Font Mono` for missing icons.
Ghostty, Kitty, Foot, Waybar, rofi, and mako request `monospace`; do not put the
chosen family separately in their configurations.

`home/fonts/profiles.nix` chooses the rendering policy automatically:

- **bitmap** for Terminus, Cozette, Dina, and Oldschool PC `Bm` families:
  antialiasing off, full hinting, no subpixel color rendering.
- **outline** for the other families: antialiasing on, slight hinting, no
  subpixel color rendering. This includes scalable pixel-style outlines such
  as Departure Mono and Terminess; it does not guarantee pixel-perfect edges
  at fractional display scales.

The rules match only the selected family; unrelated proportional fonts keep
NixOS defaults. Ghostty uses the same profile for its own FreeType rendering
flags. Only Terminus gets its existing native-size zoom steps. Other fonts
use ordinary one-point zoom; bitmap alternatives may still need a native size.
Nerd Font icons retain their own artwork even when included in a patched font.

## Installed choices

Use Font Manager (`font-manager`) to compare families with your usual letters,
punctuation, and prompt/Waybar symbols:

- `Terminus`
- `Terminess Nerd Font Mono`
- `Departure Mono` or `DepartureMono Nerd Font Mono`
- `Cozette` or `CozetteVector`
- `IBM Plex Mono` or `BlexMono Nerd Font Mono`
- Oldschool PC families, for example `PxPlus IBM VGA 8x16`

After changing the variable, activate Home Manager and restart the affected
applications. Fully exit Ghostty, including its persistent instance, before
checking a new family. The kernel console remains separately configured in
`modules/fonts.nix` because it uses PSF fonts rather than Fontconfig.

## Where the files are

- `modules/fonts.nix`: installed system font packages and console font.
- `home/fonts/`: source for user aliases and rendering profiles.
- `~/.config/fontconfig/conf.d/52-hm-default-fonts.conf`: generated user aliases.
- `~/.config/fontconfig/conf.d/90-gnesha-monospace-rendering.conf`: generated
  rendering profile (the exact generated filename is listed by `ls` below).
- `/etc/fonts/fonts.conf` and `/etc/fonts/conf.d/`: NixOS-generated system
  configuration, including paths to the packaged fonts.
- `/nix/store/.../share/fonts/`: actual packaged font files.

`~/.local/share/fonts` is for manually installed fonts. An empty directory is
normal; Nix does not copy its packages there. Font Manager is a browser here;
use `variables.nix` to persist a choice instead of creating competing GUI rules.

Inspect the active state with:

```sh
ls -l ~/.config/fontconfig/conf.d /etc/fonts/conf.d
fc-match -f '%{family}\n%{file}\n' monospace
fc-match -f 'antialias=%{antialias} hintstyle=%{hintstyle} rgba=%{rgba}\n' monospace
fc-list -f '%{family}\n' | sort -u
```

A successful build does not activate the alias. The `fc-match` results above
must be checked again after Home Manager activation.
