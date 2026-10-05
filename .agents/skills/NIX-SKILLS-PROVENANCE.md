# nix-skills provenance

Source: https://github.com/olafkfreund/nix-skills
Revision: `f5c8e8b3b3255e323e5b84192d0b6ed2e79ef4f4`
Installed: 2026-10-05 using the Codex skill-installer helper.

All ten directories from upstream `skills/` are installed here unchanged.
Each skill retains its bundled references, source metadata, and licences.
The upstream repository licence is included as `NIX-SKILLS-LICENSE`.

Repository AGENTS.md and the gneshaos-maintenance skill take precedence over
these supplemental skills, including requirements for worktrees, validation,
and explicit approval before system activation or destructive operations.

To update, install the selected upstream revision into a fresh directory,
review its changes, replace only these ten skill directories in a worktree,
and update this revision. Preserve each skill's upstream licence files.
