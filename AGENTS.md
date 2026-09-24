# Repository Guidelines

GneshaOS is a declarative NixOS and Home Manager configuration. Keep changes
small, reviewable, reproducible, and safe to evaluate without changing the
running machine.

## Project Structure

- `flake.nix` is the entry point and exposes the `cf-fv1` NixOS and Home
  Manager configurations.
- `hosts/cf-fv1/` contains host services and hardware integration.
  `hardware-configuration.nix` is generated; do not edit it manually.
- `modules/` contains reusable NixOS modules, while `home/` contains the
  user environment. Home layers use `default.nix` entry points and focused
  modules such as `home/programs/ncdu.nix`.
- `system-parameters.nix` stores stable machine/account values;
  `home/variables.nix` stores editable desktop preferences.
- `wallpapers/` contains visual assets and `docs/` contains user-facing
  documentation. There is no separate application source or test directory.

## Supplemental NixOS Management Reference

For broader NixOS tasks such as installation, remote deployment, image building,
impermanence, LUKS, or monitoring, consult `skills/nixos-managing/SKILL.md` and
its linked references. This upstream material is general guidance: this
repository's safety rules and `gneshaos-maintenance` skill take precedence.

## Build and Validation

Run checks from the repository root:

```sh
nix flake check --show-trace
nix-instantiate --parse path/to/changed-file.nix
nixos-rebuild build --flake .#cf-fv1
nix build --no-link '.#homeConfigurations."lg@cf-fv1".activationPackage'
```

These commands evaluate, parse, or build without activating the system. Run
`git diff --check` before committing. The project has no test framework or
coverage requirement; validation consists of Nix parsing, flake checks, and
build-only evaluation of affected outputs.

## Style and Naming

Use two-space indentation and existing Nix formatting. Prefer declarative
options and packaged tools over embedded shell code. Name module directories
by concern (`programs/`, `desktop/`, `services/`) and use `default.nix` as
their entry point. Keep stable values in `system-parameters.nix` and user
tweaks in `home/variables.nix`, with comments describing editable settings.

## Commits and Pull Requests

Use concise imperative commit subjects, for example `Add ncdu defaults` or
`Organize Home Manager layers`. A pull request should explain the behavior
changed, list validation commands and results, link related issues when
applicable, and include screenshots for visible desktop changes.

After each logical generation of changes is complete and validated, create a
focused commit and push it to the configured upstream. Include only work for
that generation; preserve unrelated staged and unstaged changes. Do not
force-push. If validation or pushing is blocked, report the reason rather than
claiming the generation is complete.

## Safety and Configuration

Inspect `git status --short` first and preserve unrelated work. Never commit
passwords, tokens, private keys, or machine secrets. Do not modify
`flake.lock`, generated hardware configuration, or machine-local ignored files
unless explicitly requested. Do not run `sudo`, `nixos-rebuild switch/boot`,
installation, disk, or destructive store commands without explicit approval.
