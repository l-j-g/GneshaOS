# Home Manager entry point. Keep this file focused on shared imports and
# account-level settings; user-tunable preferences live in variables.nix.

{
  inputs,
  params,
  ...
}:

{
  imports = [
    ./preferences
    ./fonts
    ./cli
    ./programs
    ./services
    ./theme
    ./desktop
    inputs.nix-index-database.homeModules.nix-index
    inputs.nix-colors.homeManagerModules.default
  ];

  home.username = params.userSettings.userName;
  home.homeDirectory = params.userSettings.homeDirectory;
  home.stateVersion = "25.05";
}
