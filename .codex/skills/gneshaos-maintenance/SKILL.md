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

Run every applicable check from the repository root. Validation is cumulative:
later checks do not replace earlier ones.

1. For every change, run `git diff --check` and inspect both `git diff` and
   `git diff --cached`. The worktree may contain changes in both layers.
2. Parse every changed `.nix` file with
   `nix-instantiate --parse <file> >/dev/null`.
3. Syntax-check changed Fish files with `fish --no-execute <file>`. Use the
   language's non-mutating syntax check for other scripts.
4. For any evaluated configuration change, run
   `nix flake check --show-trace`.
5. For changes under `hosts/`, `modules/`, `flake.nix`, or system parameters,
   run `nixos-rebuild build --flake .#<host>`.
6. For changes under `home/`, `flake.nix`, or parameters consumed by Home
   Manager, run
   `nix build --no-link '.#homeConfigurations."<user>@<host>".activationPackage'`.

Discover valid targets instead of assuming them:

```sh
nix eval --json .#nixosConfigurations --apply builtins.attrNames
nix eval --json .#homeConfigurations --apply builtins.attrNames
```

Build commands may be skipped when prerequisites are unavailable or the cost is
disproportionate. Report the exact reason; never claim an unrun check passed.

## Protect the machine

Do not run `sudo`, `nixos-rebuild switch`, `nixos-rebuild boot`, `nh os
switch`, `nh os boot`, `nh home switch`, installation, partitioning,
TPM/LUKS enrollment, or destructive Nix store commands without explicit user
approval. Treat helper commands such as `rebuild`, `rebuild-boot`, `retest`,
and `home-rebuild` as activation commands, not validation commands.

## Report the result

Lead with the outcome. List changed paths, validation commands and their exact
results, then call out skipped checks, remaining risks, and any activation the
user may choose to perform. Do not imply that a successful build activated the
configuration.
