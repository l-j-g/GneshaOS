# Home Manager environment

This tree defines the user environment shared by discovered NixOS hosts in six
layers: `programs/` (every installed program), `desktop/` (the compositor
session), `shell/`, `services/` (user services that are not a program's
configuration), `theme/`, and `fonts/`. System font packages and console fonts
are configured by `modules/fonts.nix`. `fonts/` maps the selected family from
`variables.nix` to Fontconfig's `monospace` alias and supplies the matching
rendering profile.
Each layer has a conventional `default.nix` entry point and focused modules
for individual concerns.

Inside `programs/`, one file per program (`lf.nix`, `nnn.nix`) becomes a
directory with a `default.nix` when the program also ships helper scripts or
configuration trees (`lf/`, `nnn/`, `nvim/`, `terminals/`). A program module
owns its own packages: anything it configures is installed by that module, not
by the list in `programs/default.nix`, which holds only programs with no
configuration of their own.

Edit `variables.nix` for desktop preferences such as the theme, display scale,
window gaps, terminal font family, and font sizes. Stable account, machine, and
hardware values are kept in the repository-root `system-parameters.nix`. A
literal belongs in `variables.nix` only when a user might change it, when it
appears in more than one module, or when it names a machine; everything else
stays next to its single consumer.
