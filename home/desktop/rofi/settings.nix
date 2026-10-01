# Gnesha Settings: the rofi editor for the preferences in home/variables.nix.
#
# This module supplies only what Nix knows: which terminals are installed and the
# font sizes a bitmap face accepts. The editor builds its own rows from the
# comments in home/variables.nix, so a preference is described in one place.

{
  config,
  lib,
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

  settingsConfig = pkgs.writeText "gnesha-settings.json" (builtins.toJSON {
    repo = params.systemSettings.flakePath;
    host = params.systemSettings.hostName;
    terminal = variables.terminal;
    stateRoot = "${config.home.homeDirectory}/.local/state/gnesha-activation";
    fish = "${pkgs.fish}/bin/fish";
    terminals = terminals;
    themeNames = "${config.home.homeDirectory}/.config/gnesha/theme-names";
    fontSizes = import ../../programs/terminals/font-sizes.nix;
  });
  settings = pkgs.writeShellApplication {
    name = "gnesha-settings";
    runtimeInputs = [ pkgs.python3 pkgs.nix pkgs.fontconfig pkgs.libnotify ];
    text = ''
      export PATH="${config.home.profileDirectory}/bin:/run/current-system/sw/bin:$PATH"
      exec ${pkgs.python3}/bin/python3 ${./scripts/settings.py} ${settingsConfig}
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
