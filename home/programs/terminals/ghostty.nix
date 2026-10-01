# Ghostty terminal — selectable family with bitmap-aware rendering and zoom.

{
  config,
  lib,
  pkgs,
  variables,
  fontProfile,
  ...
}:

let
  v = import ../../theme/palette.nix { inherit config pkgs; };
  p = v.palette; # raw hex, no '#'
  fontSizeValues = import ./font-sizes.nix;
  fontSizeTable = size:
    if size == variables.terminalFontSize then null else "font-size-${toString size}";

  # Terminus is a bitmap font, so one-point changes can select a missing face
  # and make FreeType scale it. Keep Ctrl+=/Ctrl+- on the native faces shipped
  # by terminus_font instead. Ghostty key tables keep the sequence statefully,
  # without Sway intercepting and re-injecting the key through wtype.
  fontSizeSteps = lib.imap0
    (index: size:
      let
        previous = if index == 0 then null else builtins.elemAt fontSizeValues (index - 1);
        next = if index + 1 == builtins.length fontSizeValues then null else builtins.elemAt fontSizeValues (index + 1);
      in
      {
        table = fontSizeTable size;
        up = next;
        upTable = if next == null then fontSizeTable size else fontSizeTable next;
        down = previous;
        downTable = if previous == null then fontSizeTable size else fontSizeTable previous;
      })
    fontSizeValues;

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
  assertions = [
    {
      assertion = !fontProfile.terminusZoom || builtins.elem variables.terminalFontSize fontSizeValues;
      message = "terminalFontSize must be one of the supported bitmap sizes: ${lib.concatMapStringsSep ", " toString fontSizeValues}.";
    }
  ];

  programs.ghostty = {
    enable = true;
    settings = {
      # Fontconfig owns family selection and the symbol fallback.
      "font-family" = "monospace";
      "font-size" = variables.terminalFontSize;
      keybind = if fontProfile.terminusZoom then fontKeybinds else [
        "ctrl+==increase_font_size:1"
        "ctrl++=increase_font_size:1"
        "ctrl+-=decrease_font_size:1"
        "ctrl+0=reset_font_size"
      ];

      # Ghostty renders with FreeType directly; share the Fontconfig profile's
      # antialiasing choice instead of maintaining an independent preference.
      "freetype-load-flags" = fontProfile.freetypeFlags;
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
