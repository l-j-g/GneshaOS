# swaylock — matrix-themed lock screen.

{
  config,
  pkgs,
  lib,
  ...
}:

let
  v = import ./vars.nix { inherit config pkgs; };
in
{
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock;
    settings = {
      color = v.bg;
      insideColor = v.bg;
      ringColor = v.accentDark;
      keyHlColor = v.accent;
      bsHlColor = v.critical;
      lineColor = v.bg;
      insideClearColor = v.bg;
      ringClearColor = v.accent;
      insideVerColor = v.bg;
      ringVerColor = v.accent;
      insideWrongColor = v.bg;
      ringWrongColor = v.critical;
      textClearColor = v.accent;
      textVerColor = v.accent;
      textWrongColor = v.critical;
    };
  };
}
