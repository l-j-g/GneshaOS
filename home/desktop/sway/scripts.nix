# Vendored sway helper scripts (from the Manjaro sway scripts, adapted for
# Nix) and the nwg-wrapper help overlay assets. Scripts land in
# ~/.config/sway/scripts and are added to PATH.
#
# One script is generated from a template so its machine-specific value comes
# from the stable system parameters and home/variables.nix:
#   - scale.sh: the scale "default" resets to (matches sway config)
#   - theme-picker: selects a Base16 theme and previews it live
#   - theme-preview: applies a selected Base16 palette to the running desktop
#   - ghostty-font-size-notify: reports native Ghostty font-size changes

{
  config,
  pkgs,
  lib,
  params,
  variables,
  ...
}:

let
  user = params.userSettings;
  system = params.systemSettings;
  # Scripts we install raw (no parameter substitution needed).
  swayScripts = lib.filterAttrs
    (name: _: !builtins.elem name [ "scale.sh" "theme-picker" "theme-preview" "ghostty-font-size-notify" ])
    (builtins.readDir ./scripts);
  installScript = name: {
    source = ./scripts/${name};
    executable = true;
  };
  # scale.sh: "default" resets to the sway-configured scale, so resetting
  # scaling can never diverge from the compositor config.
  scaleScript = lib.replaceStrings
    [ "__DEFAULT_SCALE__" ]
    [ variables.displayScale ]
    (builtins.readFile ./scripts/scale.sh);
  themePreviewScript = lib.replaceStrings
    [ "__TERMINAL_FONT_SIZE__" ]
    [ (toString variables.terminalFontSize) ]
    (builtins.readFile ./scripts/theme-preview);
  themePickerScript = lib.replaceStrings
    [ "__HOME_PROFILE__" ]
    [ "${user.userName}@${system.hostName}" ]
    (builtins.readFile ./scripts/theme-picker);
  ghosttyFontSizeNotifyScript = lib.replaceStrings
    [ "__DEFAULT_FONT_SIZE__" ]
    [ (toString variables.terminalFontSize) ]
    (builtins.readFile ./scripts/ghostty-font-size-notify);
  nwgWrapperStyle = lib.replaceStrings
    [ "__TERMINAL_FONT_SIZE__" ]
    [ (toString variables.terminalFontSize) ]
    (builtins.readFile ./nwg-wrapper/style.css);
in
{
  home.sessionPath = [ "$HOME/.config/sway/scripts" ];
  home.sessionVariables.GNESHA_FLAKE_PATH = system.flakePath;
  home.sessionVariables.GNESHA_TERMINAL_FONT_SIZE = toString variables.terminalFontSize;

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
    ".config/sway/scripts/ghostty-font-size-notify" = {
      text = ghosttyFontSizeNotifyScript;
      executable = true;
    };
    ".config/nwg-wrapper/help.sh".source = ./nwg-wrapper/help.sh;
    ".config/nwg-wrapper/style.css".text = nwgWrapperStyle;
  };
}
