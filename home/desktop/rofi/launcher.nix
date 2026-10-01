{ config, lib, pkgs, variables, ... }:
let
  launcher = pkgs.writeShellScriptBin "gnesha-rofi" ''
    # Rofi must be able to launch the user's installed applications.
    export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.rofi ]}:${config.home.profileDirectory}/bin:/run/current-system/sw/bin:$PATH
    exec ${pkgs.dash}/bin/dash ${./scripts/launcher} "$@"
  '';
in
{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    terminal = variables.terminal;
  };
  home.packages = [ launcher ];
  # Keep existing Sway bindings and the theme picker working at their old path.
  home.file.".config/sway/scripts/gnesha-rofi" = {
    source = "${launcher}/bin/gnesha-rofi";
    executable = true;
  };
}
