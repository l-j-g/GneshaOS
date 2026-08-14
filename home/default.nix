{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./shell.nix
    ./editors.nix
    ./apps.nix
    ./theme.nix
    ./desktop
    inputs.nix-colors.homeManagerModules.default
  ];

  home.username = "lg";
  home.homeDirectory = "/home/lg";
  home.stateVersion = "25.05";
}
