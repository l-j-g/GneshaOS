# Ghostty terminal — bitmap Terminus with a Nerd Font symbol fallback.

{
  config,
  lib,
  pkgs,
  variables,
  ...
}:

let
  v = import ../../theme/palette.nix { inherit config pkgs; };
  p = v.palette; # raw hex, no '#'

  # Terminus is a bitmap font, so one-point changes can select a missing face
  # and make FreeType scale it. Keep Ctrl+=/Ctrl+- on the native faces shipped
  # by terminus_font instead. Ghostty key tables keep the sequence statefully,
  # without Sway intercepting and re-injecting the key through wtype.
  fontSizeSteps = [
    {
      table = null;
      up = 18;
      upTable = "font-size-18";
      down = 14;
      downTable = "font-size-14";
    }
    {
      table = "font-size-12";
      up = 14;
      upTable = "font-size-14";
      down = null;
      downTable = "font-size-12";
    }
    {
      table = "font-size-14";
      up = 16;
      upTable = null;
      down = 12;
      downTable = "font-size-12";
    }
    {
      table = "font-size-18";
      up = 20;
      upTable = "font-size-20";
      down = 16;
      downTable = null;
    }
    {
      table = "font-size-20";
      up = 22;
      upTable = "font-size-22";
      down = 18;
      downTable = "font-size-18";
    }
    {
      table = "font-size-22";
      up = 24;
      upTable = "font-size-24";
      down = 20;
      downTable = "font-size-20";
    }
    {
      table = "font-size-24";
      up = 28;
      upTable = "font-size-28";
      down = 22;
      downTable = "font-size-22";
    }
    {
      table = "font-size-28";
      up = 32;
      upTable = "font-size-32";
      down = 24;
      downTable = "font-size-24";
    }
    {
      table = "font-size-32";
      up = null;
      upTable = "font-size-32";
      down = 28;
      downTable = "font-size-28";
    }
  ];

  bindingName = table: key: if table == null then key else "${table}/${key}";
  transition = table: key: size: nextTable:
    [ "${bindingName table key}=${if size == null then "ignore" else "set_font_size:${toString size}"}" ]
    ++ lib.optional (table != null && nextTable != table) "chain=deactivate_key_table"
    ++ lib.optional (nextTable != null && nextTable != table)
      "chain=activate_key_table:${nextTable}";
  reset = table:
    [ "${bindingName table "ctrl+0"}=reset_font_size" ]
    ++ lib.optional (table != null) "chain=deactivate_key_table";
  fontKeybinds = lib.concatLists (
    map
      (
        {
          table,
          up,
          upTable,
          down,
          downTable,
        }:
        (transition table "ctrl+=" up upTable)
        ++ (transition table "ctrl++" up upTable)
        ++ (transition table "ctrl+-" down downTable)
        ++ (reset table)
      )
      fontSizeSteps
  );
in
{
  programs.ghostty = {
    enable = true;
    settings = {
      # Fontconfig maps the first family to bitmap Terminus. The second family
      # supplies Nerd Font symbols only when Terminus lacks the codepoint.
      "font-family" = [
        "monospace"
        "Symbols Nerd Font Mono"
      ];
      "font-size" = variables.terminalFontSize;
      keybind = fontKeybinds;

      # Use hard 1-bit glyph edges for the pixel font on Linux/FreeType.
      "freetype-load-flags" = "monochrome";
      # Ordinary launches reuse Ghostty's persistent systemd user instance.
      # CLI commands using -e still intentionally start a dedicated instance.
      "gtk-single-instance" = true;
      "confirm-close-surface" = false;
      "cursor-style" = "bar";
      "window-padding-x" = 8;
      "window-padding-y" = 8;

      background = p.base00;
      foreground = p.base05;
      "selection-foreground" = p.base06;
      "selection-background" = p.base02;
      palette = [
        "0=${p.base03}"
        "1=${p.base08}"
        "2=${p.base0B}"
        "3=${p.base0A}"
        "4=${p.base0D}"
        "5=${p.base0E}"
        "6=${p.base0C}"
        "7=${p.base05}"
        "8=${p.base04}"
        "9=${p.base08}"
        "10=${p.base0B}"
        "11=${p.base0A}"
        "12=${p.base0D}"
        "13=${p.base0E}"
        "14=${p.base0C}"
        "15=${p.base07}"
      ];
    };
  };
}
