# GneshaOS Program Structure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Make the program list easy to present and remove Ghostfolio.

**Architecture:** Keep programs/default.nix as the program list, with only natural
shells, editors and terminals groups. Program-specific configuration lives in
named modules. Nix workflow helpers retain their separate owner.

**Tech Stack:** NixOS, Home Manager, Nix flakes.

**Spec:** ../specs/2026-10-15-demo-structure-design.md

## Global Constraints

Preserve non-Ghostfolio behavior, packages and preferences. Preserve unrelated
main-checkout changes. Do not modify flake.lock, build, activate or delete data.
Use the existing refactor/demo-structure worktree. Run Nix commands there.

## Review Focus

- Moved Neovim files retain their relative paths to Lua and theme assets.
- Shell helper references resolve after moving the Fish module.
- Existing unstaged Yazi additions remain available after integration.
- Media/proxy checks retain independent coverage after Ghostfolio removal.
- Parameter validation no longer requires removed Ghostfolio fields.

### Task 1: Flatten the program composition with natural groups

Files: home/programs/default.nix, home/programs/editors/, home/programs/shells/,
home/shell/default.nix, home/shell/interactive.nix and affected documentation.

Interface: existing Home Manager options, params and variables are unchanged.

- [x] Record current program imports and package inventory; inspect main-checkout
      Yazi changes without copying or committing them.
- [x] Move Neovim and Emacs into editors/; add its default.nix and fix relative
      paths, documentation and references to moved files.
- [x] Move Fish configuration and its supporting rg-fzf.fish to shells/;
      separate direnv, fzf and zoxide configuration into named modules and list
      shell packages in shells/default.nix. Keep AirVPN helper configuration in
      home/shell/airvpn.nix alongside its existing helper script.
- [x] Update program and shell entry points; preserve standalone package order
      and program behavior. Check imports, package inventory and moved paths.

### Task 2: Remove Ghostfolio and clarify flake checks

Files: modules/ghostfolio.nix, checks/ghostfolio-import-recovery-stubs.sh,
flake.nix, checks/default.nix, hosts/cf-fv1/default.nix, both root parameter
files, docs/development.md, docs/user-parameters.md, docs/recovery.md,
hosts/cf-fv1/README.md and TODO.

Interface: remaining flake check names and exported configurations stay stable.

- [x] Remove Ghostfolio module, host wiring, parameter fields and validation.
- [x] Remove its fixtures and checks; retain independent AirVPN, media and proxy
      assertions. Extract remaining check construction to checks/default.nix,
      passing explicit inputs and fixing source paths relative to checks/.
- [x] Remove obsolete documentation and TODO requirements, retaining unrelated
      portions of mixed sections. Search tracked source for remaining references.

### Task 3: Document, validate and integrate

Files: README.md and relevant ownership documentation.

Interface: documented paths match the resulting tree.

- [x] Document default-to-program-to-configuration pattern and a short talk
      walkthrough, including separate system/Home Manager activation.
- [x] Review diff and run git diff --check. Parse every changed Nix file and
      syntax-check changed scripts. Review relocation paths and package lists.
- [x] Run nix flake check --no-build --show-trace and evaluate both system and
      Home Manager derivation paths. Report any evaluation requiring builds.
- [x] Commit validated changes, merge while preserving unrelated dirty work,
      and push the configured upstream. Report evaluation separately from
      pending build and runtime verification.

## Validation results

- All 17 changed Nix files parsed and passed nixfmt checks; moved Fish helper
  and complete evaluated Fish startup passed non-mutating syntax checks.
- `nix flake check --no-build --show-trace` passed with import-from-derivation
  disabled, as did both system and Home Manager derivation evaluations.
- Before/after evaluation preserved all 146 package entries, selected program
  enablement, Fish startup/aliases/abbreviations, session variables/path and
  generated file inventory. Workflow initialization uses `lib.mkBefore` to
  preserve its original ordering after regrouping modules.
- Local Markdown links resolve; independent review found no merge blockers.
- Removed the now-unused `containersDirectory` parameter: media uses
  `arrComposePath`, and no remaining module consumed the old value.
- Build and runtime verification pending. No activation or application-data
  changes were performed.
