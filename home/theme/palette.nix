# Shared palette aliases for the desktop modules.
# The source of truth for palette values is home/theme/default.nix; this file only
# derives convenient CSS/Sway and semantic aliases from config.colorScheme.
#
# nix-colors stores colors WITHOUT the leading '#', so this module re-adds it
# for CSS/Sway/rofi-style contexts, while `colors` exposes the raw hex for
# apps like Kitty that want bare RRGGBB.
{ config, pkgs, ... }:

let
  palette = config.colorScheme.palette;
  ansi = import ./ansi-palette.nix { inherit palette; };
  hash = c: "#${c}";
  brightness = color:
    let
      # pkgs.lib keeps this importable from modules that pass only config/pkgs.
      channel = offset: pkgs.lib.fromHexString (builtins.substring offset 2 color);
    in
    299 * channel 0 + 587 * channel 2 + 114 * channel 4;
in
{
  # raw palette (no '#') — for Kitty etc.
  inherit palette ansi;

  # Perceived lightness of the selected theme, so modules can pick a matching
  # light or dark variant of their own instead of hard-coding one.
  dark = brightness palette.base00 < brightness palette.base05;

  # CSS / Sway style (with '#')
  bg = hash palette.base00;
  surface = hash palette.base01;
  selection = hash palette.base02;
  subtleBg = hash palette.base03;
  dim = hash palette.base04;
  foreground = hash palette.base05;
  light = hash palette.base06;
  lightest = hash palette.base07;
  red = hash palette.base08;
  orange = hash palette.base09;
  yellow = hash palette.base0A;
  accent = hash palette.base0B;
  cyan = hash palette.base0C;
  blue = hash palette.base0D;
  magenta = hash palette.base0E;
  accentDark = hash palette.base0F;

  # Semantic aliases
  warning = hash palette.base0A;
  critical = hash palette.base08;
  subtle = hash palette.base04;
}
