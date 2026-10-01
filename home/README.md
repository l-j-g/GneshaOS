# Home Manager environment

This tree defines the user environment shared by discovered NixOS hosts:
shell, editors, programs, services, desktop configuration, and theme. System
font packages and console fonts are configured by `modules/fonts.nix`.
`fonts/` maps the selected family from `variables.nix` to Fontconfig's
`monospace` alias and supplies the matching rendering profile.
Each layer has a conventional `default.nix` entry point and focused modules
for individual concerns.

Edit `variables.nix` for desktop preferences such as the theme, display scale,
window gaps, terminal font family, and font sizes. Stable account, machine, and
hardware values are kept in the repository-root `system-parameters.nix`.
