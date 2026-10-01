# Yazi has no package entry in programs/default.nix: Home Manager's
# programs.yazi module installs its own package when enabled.

{
  ...
}:

{
  programs.yazi = {
    enable = true;
  };
}
