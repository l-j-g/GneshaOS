# Nix workflow and activation helpers, plus the AirVPN command wrapper.
# Interactive shell configuration lives in home/programs/shells.
{
  imports = [
    ./airvpn.nix
    ./workflows.nix
  ];
}
