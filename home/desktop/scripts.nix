# Vendored sway helper scripts (from the Manjaro sway scripts, adapted for
# Nix) and the nwg-wrapper help overlay assets. Scripts land in
# ~/.config/sway/scripts and are added to PATH.
#
# One script is generated from a template so its machine-specific value comes
# from the top-level params (see params.example.nix):
#   - scale.sh: the scale "default" resets to (matches sway config)

{
  config,
  pkgs,
  lib,
  params,
  ...
}:

let
  u = params.userSettings;
  screenshotDir = lib.replaceStrings [ "~" ] [ config.home.homeDirectory ] u.screenshotDir;
  # Scripts we install raw (no parameter substitution needed).
  swayScripts = lib.filterAttrs
    (name: _: name != "scale.sh" && name != "screenshot.sh")
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
  screenshotScript = lib.replaceStrings
    [ "__SCREENSHOT_DIR__" "__SCREENSHOT_UPLOAD_URL__" ]
    [ screenshotDir u.screenshotUploadUrl ]
    (builtins.readFile ./scripts/screenshot.sh);
in
{
  home.sessionPath = [ "$HOME/.config/sway/scripts" ];

  home.file = (builtins.listToAttrs (map (name: {
    name = ".config/sway/scripts/${name}";
    value = installScript name;
  }) (builtins.attrNames swayScripts))) // {
    ".config/sway/scripts/scale.sh" = {
      text = scaleScript;
      executable = true;
    };
    ".config/sway/scripts/screenshot.sh" = {
      text = screenshotScript;
      executable = true;
    };
    ".config/nwg-wrapper/help.sh".source = ./nwg-wrapper/help.sh;
    ".config/nwg-wrapper/style.css".source = ./nwg-wrapper/style.css;
  };
}
