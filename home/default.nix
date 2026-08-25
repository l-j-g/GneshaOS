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
    ./neovim.nix
    ./apps.nix
    ./theme.nix
    ./desktop
    inputs.nix-index-database.homeModules.nix-index
    inputs.nix-colors.homeManagerModules.default
  ];

  home.username = params.userSettings.userName;
  home.homeDirectory = params.userSettings.homeDirectory;
  home.stateVersion = "25.05";

  # Top-level desktop asset: the repository `wallpaper` symlink selects the
  # active preview from `wallpapers/` and Sway applies this generated path.
  home.file."wallpapers".source = ../wallpapers;
  home.file."wallpaper".source = ../wallpaper;
  xdg.configFile."sway/generated_background.svg".source = ../wallpaper;
}
