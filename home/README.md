# Home Manager environment

This tree defines the user environment shared by discovered NixOS hosts:
shell, editors, programs, services, desktop configuration, fonts, and theme.
Programs and user services live in their respective subdirectories, with one
focused module per concern. It consumes `params` supplied by `flake.nix`; keep
user-facing preferences in the root `params.nix`, not in individual home
modules.
