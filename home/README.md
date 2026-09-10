# Home Manager environment

This tree defines the user environment shared by discovered NixOS hosts:
shell, editors, programs, services, desktop configuration, and theme. System
fonts and console fonts are configured by `modules/fonts.nix`.
Each layer has a conventional `default.nix` entry point and focused modules
for individual concerns.

Edit `variables.nix` for desktop preferences such as the theme, display scale,
window gaps, terminal font family, and font sizes. Stable account, machine, and
hardware values are kept in the repository-root `system-parameters.nix`.
