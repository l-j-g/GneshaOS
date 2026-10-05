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

## Working in a Worktree

Do not make source changes in the main checkout. Start every task in its own
worktree so two agents can work in this repository at the same time without
overwriting each other:

```sh
git worktree add -b <topic> .worktrees/<topic> HEAD
```

Work inside `.worktrees/<topic>/`, and run every `nix` command from there so the
flake resolves to that worktree. `.worktrees/` is ignored, so nothing extra lands
in the index. When the work is validated, commit on the topic branch.

- If an integrating agent created or assigned the task, return the branch name
  to that agent for merging; do not merge or push it yourself.
- If a human user requested the task directly, merge your validated topic branch
  into the main branch and push it to the configured upstream. You are responsible
  for integration; do not leave it pending for another agent. The main checkout
  may be used for the merge, while preserving unrelated staged and unstaged work.

Never force-push, never `git checkout` a path that another worktree owns, and
never reset the main
checkout's index — leave unrelated staged and unstaged work alone.

## Supplemental NixOS Management Reference

For broader NixOS tasks such as installation, remote deployment, image building,
impermanence, LUKS, or monitoring, consult `skills/nixos-managing/SKILL.md` and
its linked references. The repository instructions here and the
`gneshaos-maintenance` skill take precedence over that supplemental reference.
See `skills/nixos-managing/PROVENANCE.md` for its source, license, and local
adaptations. Agents delegated tasks by an integrating agent return changes for
integration and do not push; agents handling direct human requests follow the
merge and push policy above.

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
tweaks in `home/variables.nix`, which stays a plain file of literals: every
preference gets a comment above it, and that comment is the description the
Gnesha Settings editor shows, so preferences are catalogued nowhere else.

Avoid `with` expressions in repository-owned Nix code. Use explicit attribute
paths such as `pkgs.rustup`, `pkgs.vimPlugins.nvim-lspconfig`, and
`config.boot.kernelPackages.acpi_call`. For repeated names, a narrowly scoped
`let` with `inherit (pkgs) name;` is acceptable. Qualify callback attributes too
(for example, `p: [ p.tree-sitter-nix ]`). This keeps name origins visible to
readers and static analysis. Preserve list order when refactoring; do not
replace ordered lists with `builtins.attrValues`.

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
