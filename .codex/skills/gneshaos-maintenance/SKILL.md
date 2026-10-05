---
name: gneshaos-maintenance
description: Safely audit, modify, review, and validate the GneshaOS NixOS and Home Manager repository. Use for changes to flake.nix, system-parameters.nix, home/variables.nix, hosts/, modules/, home/, desktop scripts, local Codex workflow files, or repository documentation, and for diagnosing evaluation or build failures without activating the machine.
---

# Maintain GneshaOS

Follow the repository's `AGENTS.md` first. Keep the running system unchanged
unless the user explicitly requests activation.

## Inspect before editing

1. Run `git status --short` and preserve unrelated staged, unstaged, and
   untracked work.
2. Read the relevant `default.nix` entry points and trace arguments back to
   their source before changing a leaf module.
3. Use these ownership boundaries:
   - `system-parameters.nix`: stable machine, account, hardware, and path values.
   - `home/variables.nix`: editable desktop and user preferences.
   - `hosts/<host>/`: host composition, services, and hardware integration.
   - `modules/`: reusable NixOS behavior and options.
   - `home/`: shared Home Manager behavior.
4. Never hand-edit `hosts/*/hardware-configuration.nix`. Change `flake.lock`
   only when the user asks to update inputs.

## Make the change

- Prefer NixOS or Home Manager options and packaged programs over embedded
  shell.
- Keep a script under the layer that owns it when no declarative option fits.
- Match two-space Nix indentation and existing module structure.
- Keep the patch focused. Do not stage, unstage, discard, or rewrite unrelated
  user changes.
- Do not add credentials, tokens, private keys, recovery keys, or password
  hashes to the repository.

## Choose validation by impact

Default to parsing and evaluation; the user runs rebuilds separately. Run all
applicable checks from the task worktree, without building configuration outputs.

1. For every change, run `git diff --check` and inspect both `git diff` and
   `git diff --cached`. For documentation-only changes, stop after diff review.
2. Parse every changed `.nix` file with
   `nix-instantiate --parse <file> >/dev/null`.
3. Syntax-check changed Fish files with `fish --no-execute <file>`. Use the
   language's non-mutating syntax check for other scripts.
4. For evaluated configuration changes, run
   `nix flake check --no-build --show-trace`.
5. For changes affecting the system configuration, evaluate
   `nix eval --raw '.#nixosConfigurations.<host>.config.system.build.toplevel.drvPath'`.
6. For changes affecting Home Manager, evaluate
   `nix eval --raw '.#homeConfigurations."<user>@<host>".activationPackage.drvPath'`.
   Evaluate both outputs for shared changes.

Discover valid targets instead of assuming them:

```sh
nix eval --json .#nixosConfigurations --apply builtins.attrNames
nix eval --json .#homeConfigurations --apply builtins.attrNames
```

`--no-build` skips building flake checks. Evaluation may still fetch inputs or
trigger import-from-derivation builds; if this prevents evaluation without a
build, report the limitation rather than starting a separate build.

Passing the applicable default checks is sufficient to commit, merge, and push.
Run `nixos-rebuild build`, `nix build`, or flake checks without `--no-build` only
when the user explicitly requests build validation. Report skipped or failed
checks accurately; never claim an unrun check passed.

## Protect the machine

Do not run `sudo`, `nixos-rebuild switch`, `nixos-rebuild boot`, `nh os
switch`, `nh os boot`, `nh home switch`, installation, partitioning,
TPM/LUKS enrollment, or destructive Nix store commands without explicit user
approval. Treat helper commands such as `rebuild`, `rebuild-boot`, `retest`,
and `home-rebuild` as activation commands, not validation commands.

## Report the result

Lead with the outcome. List changed paths, validation commands and their exact
results, then call out skipped checks and remaining risks. For configuration
changes validated by evaluation only, report "evaluation passed; build and
runtime verification pending". Do not imply evaluation proves a build succeeds
or that a successful build activated the configuration.
