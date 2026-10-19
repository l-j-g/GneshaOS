# Home Manager environment

This tree defines the user environment shared by discovered NixOS hosts in six
layers: `programs/` (applications and interactive shells), `desktop/` (the compositor
session), `cli/` (Nix workflows and command helpers), `services/` (user services that are not a program's
configuration), `theme/`, and `fonts/`. System font packages and console fonts
are configured by `modules/fonts.nix`. `fonts/` maps the selected family from
`variables.nix` to Fontconfig's `monospace` alias and supplies the matching
rendering profile.
Each layer has a conventional `default.nix` entry point and focused modules
for individual concerns.

Start at `programs/default.nix`: it lists standalone packages and imports
configured programs. Natural families have their own entry points:
`programs/editors/`, `programs/shells/`, and `programs/terminals/`. Other
configured programs stay directly under `programs/`.

A configured program gets its own module, such as `git.nix`. When it also ships
supporting scripts or configuration trees, keep those together in a directory,
such as `lf/`, `nnn/`, or `editors/nvim/`. Each group's `default.nix` lists
unconfigured packages and imports configured programs. A program module owns
its primary package through Home Manager, along with its configuration.

`programs/shells/` owns Fish and its direnv, fzf and zoxide integrations.
`cli/` owns Nix rebuild/activation workflows and the AirVPN command wrapper;
supporting implementations live in `cli/scripts/`.
`home/shell/pending-count.sh` is a compatibility symlink for update-status
wrappers from older activated generations; it can be removed once those
generations are no longer used.

`desktop/default.nix` follows the same pattern: imports for configured
components and a list of standalone desktop packages. Desktop proxy settings,
cursor appearance, portal configuration and the Grimshot wrapper each have a
focused module. Browser environment settings stay with browser configuration
in `programs/browsers.nix`.

Edit `variables.nix` for desktop preferences such as the theme, display scale,
window gaps, terminal font family, and font sizes. Stable account, machine, and
hardware values are kept in the repository-root `system-parameters.nix`. A
literal belongs in `variables.nix` only when a user might change it, when it
appears in more than one module, or when it names a machine; everything else
stays next to its single consumer.
