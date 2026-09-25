# Development workflow

This repository separates evaluation and build checks from activation. Run
validation from the repository root and activate only after reviewing the
resulting diff and build.

## Before editing

Start by checking all three Git states:

```sh
git status --short
git diff
git diff --cached
```

A path can contain staged and unstaged changes at the same time. Do not assume
that `git diff` alone shows the whole pending change, and do not stage or
discard unrelated work to simplify a task.

Use the repository ownership boundaries when deciding where a value belongs:

| Concern | Source of truth |
| --- | --- |
| Stable account, machine, hardware, and path values | `system-parameters.nix` |
| Editable desktop and user preferences | `home/variables.nix` |
| Host composition and hardware integration | `hosts/<host>/` |
| Reusable NixOS behavior | `modules/` |
| Shared user environment | `home/` |

`hosts/*/hardware-configuration.nix` is generated. Do not edit it manually.
Update `flake.lock` only as a separate, intentional dependency change.

## Discover build targets

Host directories are discovered dynamically by `flake.nix`. List the actual
outputs before copying a command from an example:

```sh
nix eval --json .#nixosConfigurations --apply builtins.attrNames
nix eval --json .#homeConfigurations --apply builtins.attrNames
```

## Validation ladder

Run every row that applies to the change. All commands below are non-activating.

| Scope | Command | Purpose |
| --- | --- | --- |
| Every change | `git diff --check` | Catch whitespace and conflict-marker errors |
| Changed Nix file | `nix-instantiate --parse <file>` | Catch syntax errors quickly |
| Changed Fish file | `fish --no-execute <file>` | Parse Fish without running it |
| Evaluated configuration | `nix flake check --show-trace` | Evaluate exported flake configurations |
| NixOS or shared module | `nixos-rebuild build --flake .#<host>` | Build the system closure without activation |
| Home Manager or shared input | `nix build --no-link '.#homeConfigurations."<user>@<host>".activationPackage'` | Build the user activation package without running it |

Finish by inspecting both versions of the diff again. Record commands that
were skipped or failed; an unrun check is not a passing check.

## Activation helpers

The Fish helpers in `home/shell/nix-workflow.fish` are convenient after review,
but several of them change live state:

| Helper | Effect |
| --- | --- |
| `nixparse <file>` | Parse one Nix file; no activation |
| `nixeval <option>` | Evaluate one host option; no activation |
| `nixbuild` | Build the configured system output; no activation |
| `home-rebuild` | Activate the Home Manager profile |
| `retest` | Build and activate a temporary NixOS test generation |
| `rebuild-boot` | Set a new NixOS boot generation |
| `rebuild` | Build both outputs from one source snapshot, then activate both |
| `activation-list` / `activation-resume ID` / `activation-discard ID` | Inspect, retry, or explicitly discard a saved activation attempt |
| `update-status` | Show background build status |
| `update-review` | Review the prepared lock and system package diff |
| `update-apply` | Accept the prepared lock and activate its built outputs |

`rebuild` freezes one source snapshot and builds both NixOS and Home Manager
before activating either. Long builds run outside the shared activation lock.
The system switch, Home Manager switch, update apply, theme-picker activation,
and the normal shell activation helpers share one lock, so those activation
sequences cannot interleave.

Theme picker sessions also take a short user-state lock so previews and
preference writes are serialized. It replaces `home/variables.nix` atomically
beside the file while preserving its mode. Each background Home Manager run
writes a separate log under `~/.config/gnesha/theme-activation-logs/`; a failed
activation leaves the saved selection in place and reports that the live
preview may differ.

Each `rebuild` attempt records its input snapshot, old and candidate generations,
phase, and log under `~/.local/state/gnesha-activation/transactions/`. Candidate
GC roots and logs remain after failure. Retry the exact saved closures with
`activation-resume ATTEMPT_ID`; this does not re-evaluate the source. Use
`activation-list` to find an ID and `activation-discard ID` only when you
explicitly want to release its roots and remove its log. The system retains the
five newest completed attempts and allows at most three unresolved attempts
before asking you to resume or discard one. Attempt creation reserves capacity
under the same lock. After building outside the lock, a rebuild rechecks its
saved source snapshot under the lock and refuses to activate if the source
changed while it was building.

System and Home Manager activation is sequential, not atomic. A failed Home
Manager activation can leave the new system generation active; inspect the
recorded phase and retry or recover manually. These commands do not roll back
live databases or services automatically. Failed update applies use the same
transaction record; resume verifies the repository `flake.lock` still matches
the candidate lock before switching.

The daily `gnesha-nixpkgs-update` timer prepares a separate candidate at 05:30
local time, with up to 30 minutes of jitter. It runs only on AC power, uses one
build job and two build cores, and keeps one completed candidate under
`/var/lib/gnesha-update`. It neither edits the repository nor activates anything.
A scheduled run skipped on battery waits for the next timer/manual invocation.
Store paths shared with existing generations do not duplicate their contents,
but new versions still need disk space. Failed builds retain the last ready candidate.

Use `update-status`, `update-review`, then `update-apply` when ready. Apply checks
that the configuration still matches the candidate, writes its reviewed
`flake.lock`, and switches to the exact system and Home Manager builds. Commit
and push that lock change separately. To request another background run:

```sh
sudo systemctl start --no-block gnesha-nixpkgs-update
journalctl -fu gnesha-nixpkgs-update
```

## Dependency updates

Keep dependency updates reviewable and separate from unrelated configuration:

```sh
nix flake update nixpkgs
git diff -- flake.lock
nix flake check --show-trace
nixos-rebuild build --flake .#<host>
nix build --no-link '.#homeConfigurations."<user>@<host>".activationPackage'
```

Use `nix flake update` without an input name only when intentionally updating
all inputs.

## Codex workflow

Repository-local Codex configuration lives in `.codex/`:

- `nix_explorer` traces configuration and parameter flow without writing.
- `nix_reviewer` checks an existing diff for evaluation and machine-safety
  risks without writing.
- `nix_worker` implements a narrowly owned change in an isolated worktree.
- `$gneshaos-maintenance` provides the repository-specific edit and validation
  workflow for Codex sessions.
- `codex-nix` starts Codex in `~/.config/nix` with repository-scoped writes and
  no approval prompts, without changing the calling shell's directory.

Keep sandbox protections enabled for normal work. With the helper's no-prompt
policy, operations outside the writable scope fail instead of requesting
escalation. Commands that disable the sandbox remove that safeguard entirely.
