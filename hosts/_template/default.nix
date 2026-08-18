# Copy this directory to hosts/<host-name>/ when adding a machine.
#
# Before building, replace hardware-configuration.nix with the output of
# nixos-generate-config for that machine and add host-specific modules here.
# Keep shared consumer/user defaults in the repository-root params.nix; use
# the optional params.nix beside this file for host-specific overrides.
{
  hostName,
  ...
}:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = hostName;
  system.stateVersion = "25.05";
}
