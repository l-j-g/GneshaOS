# Vendored sway helper scripts (from the Manjaro sway scripts, adapted for
# Nix) and the nwg-wrapper help overlay assets. Scripts land in
# ~/.config/sway/scripts and are added to PATH.
#
# One script is generated from a template so its machine-specific value comes
# from the top-level params (see params.example.nix):
#   - scale.sh: the scale "default" resets to (matches sway config)
#   - theme-picker: selects a Base16 theme and previews it live
#   - theme-preview: applies a selected Base16 palette to the running desktop

{
  config,
  pkgs,
  lib,
  params,
  ...
}:

let
  u = params.userSettings;
  # Scripts we install raw (no parameter substitution needed).
  swayScripts = lib.filterAttrs
    (name: _: !builtins.elem name [ "scale.sh" "theme-picker" "theme-preview" ])
    (builtins.readDir ./scripts);
  installScript = name: {
    source = ./scripts/${name};
    executable = true;
  };
  # scale.sh: "default" resets to the sway-configured scale, so resetting
  # scaling can never diverge from the compositor config.
  scaleScript = lib.replaceStrings
    [ "__DEFAULT_SCALE__" ]
    [ u.displayScale ]
    (builtins.readFile ./scripts/scale.sh);
  themePreviewScript = lib.replaceStrings
    [ "__TERMINAL_FONT_SIZE__" ]
    [ (toString u.terminalFontSize) ]
    (builtins.readFile ./scripts/theme-preview);
  themePickerScript = lib.replaceStrings
    [ "__HOME_PROFILE__" ]
    [ "${u.userName}@${params.systemSettings.hostName}" ]
    (builtins.readFile ./scripts/theme-picker);
  nwgWrapperStyle = lib.replaceStrings
    [ "__TERMINAL_FONT_SIZE__" ]
    [ (toString u.terminalFontSize) ]
    (builtins.readFile ./nwg-wrapper/style.css);
in
{
  home.sessionPath = [ "$HOME/.config/sway/scripts" ];
  home.sessionVariables.GNESHA_FLAKE_PATH = params.systemSettings.flakePath;
  home.sessionVariables.GNESHA_TERMINAL_FONT_SIZE = toString u.terminalFontSize;

  home.file = (builtins.listToAttrs (map (name: {
    name = ".config/sway/scripts/${name}";
    value = installScript name;
  }) (builtins.attrNames swayScripts))) // {
    ".config/sway/scripts/scale.sh" = {
      text = scaleScript;
      executable = true;
    };
    ".config/sway/scripts/theme-picker" = {
      text = themePickerScript;
      executable = true;
    };
    ".config/sway/scripts/theme-preview" = {
      text = themePreviewScript;
      executable = true;
    };
    ".config/nwg-wrapper/help.sh".source = ./nwg-wrapper/help.sh;
    ".config/nwg-wrapper/style.css".text = nwgWrapperStyle;
  };
}
