# Shared palette aliases for the desktop modules.
#
# nix-colors stores colors WITHOUT the leading '#', so this module re-adds it
# for CSS/Sway/rofi-style contexts, while `colors` exposes the raw hex for
# apps like foot that want bare RRGGBB.
{ config, pkgs, ... }:

let
  palette = config.colorScheme.palette;
  hash = c: "#${c}";
in
{
  # raw palette (no '#') — for foot etc.
  inherit palette;

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
