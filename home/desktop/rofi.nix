# rofi launcher — Manjaro-style combi (drun + run), matrix-themed.

{
  config,
  pkgs,
  lib,
  ...
}:

let
  v = import ./vars.nix { inherit config pkgs; };
  # Rofi 2.x rejects inline themes passed as `@theme "<content>"`.
  # Home-manager emits a proper `@theme "custom"` when `theme` is an attrset,
  # writing the content to ~/.local/share/rofi/themes/custom.rasi.
  inherit (config.lib.formats.rasi) mkLiteral;
in
{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    terminal = "footclient";
    theme = {
      "*" = {
        background-color = mkLiteral "${v.bg}E6";
        foreground-color = mkLiteral v.foreground;
        text-color = mkLiteral v.foreground;
        border-color = mkLiteral v.accent;
        spacing = mkLiteral "2px";
      };

      window = {
        background-color = mkLiteral "${v.bg}EE";
        border = mkLiteral "2px";
        border-color = mkLiteral v.accent;
        border-radius = mkLiteral "0px";
        width = mkLiteral "50%";
        padding = mkLiteral "12px";
      };

      mainbox = {
        padding = mkLiteral "8px";
      };

      inputbar = {
        padding = mkLiteral "8px";
        background-color = mkLiteral v.surface;
        border-radius = mkLiteral "0px";
      };

      entry = {
        font = "monospace 11";
      };

      listview = {
        lines = 10;
      };

      element = {
        padding = mkLiteral "6px";
      };

      "element selected" = {
        background-color = mkLiteral v.surface;
        text-color = mkLiteral v.accent;
      };
    };
  };
}
