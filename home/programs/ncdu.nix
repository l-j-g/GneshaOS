# Ncdu defaults. This module owns the ncdu command: the wrapper below is the
# only entry point, so ncdu is not listed in programs/default.nix.

{
  config,
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
  # Match the theme's lightness instead of always rendering the dark variant.
  v = import ../theme/palette.nix { inherit config pkgs; };
in
{
  # Ncdu's config format is one command-line option per line.
  xdg.configFile."ncdu/config".text = ''
    --color=${if v.dark then "dark" else "light"}
  '';

  # ~/.local/bin is already placed before packaged applications by the shared
  # integrations module, so this wrapper is the ncdu command on PATH.
  home.file.".local/bin/ncdu" = {
    source = ncduWithAllThreads;
    executable = true;
  };
}
