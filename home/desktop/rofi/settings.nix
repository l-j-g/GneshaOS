{ config, lib, pkgs, params, variables, ... }:
let
  settingsConfig = pkgs.writeText "gnesha-settings.json" (builtins.toJSON {
    repo = params.systemSettings.flakePath;
    host = params.systemSettings.hostName;
    terminal = variables.terminal;
    stateRoot = "${config.home.homeDirectory}/.local/state/gnesha-activation";
    fish = "${pkgs.fish}/bin/fish";
    themeNames = "${config.home.homeDirectory}/.config/gnesha/theme-names";
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
