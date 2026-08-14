# Vendored sway helper scripts (from the Manjaro sway scripts, adapted for
# Nix) and the nwg-wrapper help overlay assets. Scripts land in
# ~/.config/sway/scripts and are added to PATH.
#
# Two scripts are generated from templates so their machine-specific values
# come from the top-level params (see params.example.nix):
#   - als-brightness.sh: IIO sensor path + backlight device
#   - scale.sh:          the scale "default" resets to (matches sway config)

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
  swayScripts = lib.filterAttrs (name: _: name != "als-brightness.sh" && name != "scale.sh") (builtins.readDir ./scripts);
  installScript = name: {
    source = ./scripts/${name};
    executable = true;
  };
  # als-brightness.sh: templated sensor path + backlight device.
  alsBrightness = lib.replaceStrings
    [ "__ALS_SENSOR_PATH__" "__BACKLIGHT_DEVICE__" ]
    [ u.alsSensorPath u.backlightDevice ]
    (builtins.readFile ./scripts/als-brightness.sh);
  # scale.sh: "default" resets to the sway-configured scale, so resetting
  # scaling can never diverge from the compositor config.
  scaleScript = lib.replaceStrings
    [ "__DEFAULT_SCALE__" ]
    [ u.displayScale ]
    (builtins.readFile ./scripts/scale.sh);
in
{
  home.sessionPath = [ "$HOME/.config/sway/scripts" ];

  home.file = (builtins.listToAttrs (map (name: {
    name = ".config/sway/scripts/${name}";
    value = installScript name;
  }) (builtins.attrNames swayScripts))) // {
    ".config/sway/scripts/als-brightness.sh" = {
      text = alsBrightness;
      executable = true;
    };
    ".config/sway/scripts/scale.sh" = {
      text = scaleScript;
      executable = true;
    };
    ".config/nwg-wrapper/help.sh".source = ./nwg-wrapper/help.sh;
    ".config/nwg-wrapper/style.css".source = ./nwg-wrapper/style.css;
  };
}
