# Shell entry point: interactive appearance/integrations and Nix workflows have
# separate owners so routine aliases stay independent of activation commands.
{
  imports = [
    ./interactive.nix
    ./workflows.nix
  ];
}
