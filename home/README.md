# Home Manager environment

This tree defines the user environment shared by discovered NixOS hosts:
shell, editors, applications, desktop configuration, fonts, and theme. It
consumes `params` supplied by `flake.nix`; keep user-facing preferences in the
root `params.nix`, not in individual home modules.
