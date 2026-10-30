{ pkgs, ... }:
let
  displaySettings = pkgs.writeShellApplication {
    name = "display-settings";
    runtimeInputs = [
      pkgs.systemd
      pkgs.util-linux
      pkgs.wdisplays
      pkgs.libnotify
    ];
    text = builtins.readFile ./scripts/display-settings;
  };
in
{
  home.packages = [ displaySettings ];

  xdg.desktopEntries.gnesha-displays = {
    name = "Displays";
    genericName = "Display Settings";
    comment = "Arrange presentation screens; keep open to retain the manual layout";
    exec = "${displaySettings}/bin/display-settings";
    icon = "preferences-desktop-display";
    terminal = false;
    categories = [
      "Settings"
      "HardwareSettings"
    ];
    settings.Keywords = "monitor;projector;presentation;resolution;scaling;";
  };
}
