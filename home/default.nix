# Home Manager entry point. Keep this file focused on shared imports and
# account-level settings; user-tunable preferences live in variables.nix.

{
  inputs,
  params,
  ...
}:

let
  variables = import ./variables.nix;
in
{
  imports = [
    ./shell
    ./editors
    ./programs
    ./services
    ./theme
    ./desktop
    inputs.nix-index-database.homeModules.nix-index
    inputs.nix-colors.homeManagerModules.default
  ];

  # Make the documented preference set available to every Home Manager
  # module without requiring each module to import it independently.
  _module.args = { inherit variables; };

  home.username = params.userSettings.userName;
  home.homeDirectory = params.userSettings.homeDirectory;
  home.stateVersion = "25.05";
}
