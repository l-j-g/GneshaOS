{
  config,
  pkgs,
  lib,
  inputs,
  params,
  ...
}:

{
  imports = [
    ./shell.nix
    ./editors.nix
    ./apps.nix
    ./theme.nix
    ./desktop
    inputs.nix-colors.homeManagerModules.default
  ];

  home.username = params.userSettings.userName;
  home.homeDirectory = params.userSettings.homeDirectory;
  home.stateVersion = "25.05";
}
