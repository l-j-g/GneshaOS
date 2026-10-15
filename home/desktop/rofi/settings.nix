# Gnesha Settings: the rofi editor for the preferences in home/variables.nix.
#
# This module packages the script-mode callbacks and native Nix validation,
# plus installed terminals and bitmap font sizes. The editor builds rows from the
# comments in home/variables.nix, so a preference is described in one place.

{
  config,
  pkgs,
  params,
  variables,
  ...
}:

let
  terminals = builtins.filter (name: config.programs.${name}.enable or false) [
    "foot"
    "ghostty"
    "kitty"
  ];

  settingsConfig = pkgs.writeText "gnesha-settings.json" (
    builtins.toJSON {
      repo = params.systemSettings.flakePath;
      host = params.systemSettings.hostName;
      terminal = variables.terminal;
      stateRoot = "${config.home.homeDirectory}/.local/state/gnesha-activation";
      fish = "${pkgs.fish}/bin/fish";
      terminals = terminals;
      themeNames = "${config.home.homeDirectory}/.config/gnesha/theme-names";
      fontSizes = import ../../programs/terminals/font-sizes.nix;
      validator = ./settings-validate.nix;
    }
  );
  settingsMode = pkgs.writeShellApplication {
    name = "gnesha-settings-mode";
    runtimeInputs = [
      pkgs.nix
      pkgs.jq
      pkgs.gawk
      pkgs.ripgrep
      pkgs.coreutils
      pkgs.gnused
      pkgs.util-linux
      pkgs.fontconfig
    ];
    text = ''
      export PATH="${config.home.profileDirectory}/bin:/run/current-system/sw/bin:$PATH"
      exec ${pkgs.bash}/bin/bash ${./scripts/settings.sh} ${settingsConfig} "$@"
    '';
  };
  settings = pkgs.writeShellApplication {
    name = "gnesha-settings";
    text = ''
      export PATH="${config.home.profileDirectory}/bin:/run/current-system/sw/bin:$PATH"
      exec gnesha-rofi -show settings -modes "settings:${settingsMode}/bin/gnesha-settings-mode" \
        -i -lines 12 -theme-str 'window { width: 85%; }'
    '';
  };
in
{
  home.packages = [ settings ];
  xdg.desktopEntries.gnesha-settings = {
    name = "Gnesha Settings";
    genericName = "Desktop preferences";
    comment = "Search and configure fonts, appearance, idle timers, and other preferences";
    exec = "${settings}/bin/gnesha-settings";
    icon = "preferences-system";
    terminal = false;
    categories = [ "Settings" ];
  };
}
