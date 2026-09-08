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
  liveThemeText = ''
    * {
        background-color: ${v.bg}E6;
        foreground-color: ${v.foreground};
        text-color: ${v.foreground};
        border-color: ${v.accent};
        spacing: 2px;
    }
    window {
        background-color: ${v.bg}EE;
        border: 2px;
        border-color: ${v.accent};
        border-radius: 0px;
        width: 50%;
        padding: 12px;
    }
    mainbox { padding: 8px; }
    inputbar {
        padding: 8px;
        background-color: ${v.surface};
        border-radius: 0px;
    }
    entry { font: "monospace 11"; }
    listview { lines: 10; }
    element { padding: 6px; }
    element selected {
        background-color: ${v.surface};
        text-color: ${v.accent};
    }
  '';
in
{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    terminal = "kitty";
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

  # Seed the mutable runtime theme from the declarative theme on every
  # activation. The picker may replace it temporarily between rebuilds.
  home.activation.resetGneshaRofiLiveTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD install -Dm644 ${pkgs.writeText "gnesha-rofi-live.rasi" liveThemeText} "$HOME/.config/gnesha/rofi-live.rasi"
  '';
}
