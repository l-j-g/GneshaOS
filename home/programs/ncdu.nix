# Ncdu defaults. The package stays in programs/default.nix; this module owns
# the small amount of configuration needed to make its runtime behavior useful.

{
  pkgs,
  ...
}:

let
  # CPU availability is runtime state, so it cannot be read reliably while
  # evaluating the flake. Shadow the packaged command with a Home Manager
  # wrapper that selects all currently available logical processors.
  ncduWithAllThreads = pkgs.writeShellScript "ncdu-with-all-threads" ''
    exec ${pkgs.ncdu}/bin/ncdu --threads "$(${pkgs.coreutils}/bin/nproc)" "$@"
  '';
in
{
  # Ncdu's config format is one command-line option per line.
  xdg.configFile."ncdu/config".text = ''
    --color=dark
  '';

  # ~/.local/bin is already placed before packaged applications by the shared
  # integrations module, so this wrapper transparently replaces the raw ncdu
  # command while keeping ncdu in the canonical package list.
  home.file.".local/bin/ncdu" = {
    source = ncduWithAllThreads;
    executable = true;
  };
}
