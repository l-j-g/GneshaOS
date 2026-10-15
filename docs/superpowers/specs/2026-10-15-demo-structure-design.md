# GneshaOS presentation structure and Ghostfolio removal

## Purpose

Make the repository easy to follow during a Sydney Linux User Group talk.
A category's default.nix declares its standalone packages and imports modules
for configured programs. Keep the existing system/Home Manager separation.

## Composition pattern

- Keep home/default.nix as the top-level composition and account settings.
- Make home/programs/default.nix import explicit category entry points.
- Group programs into development (editors, Git, coding agents, Node and uv),
  terminals (existing Ghostty/Kitty modules), files (file managers and file
  inspection/archive tools), browsers (Firefox, LibreWolf and Tor),
  communication (Signal, Discord and Slack), media (image/video applications),
  games (Steam and PPSSPP), and security (GPG, Kleopatra, KeePassXC and Monero).
- Each category/default.nix lists unconfigured packages directly and imports
  named modules for configured programs. Do not create one-line modules solely
  to install an unconfigured package. Preserve package-list order within groups.
- Keep shared browser zoom behavior in one helper, with Firefox and LibreWolf
  configuration in their own modules; do not duplicate the zoom implementation.
- Keep compositor/session components under home/desktop and shell behavior under
  home/shell. Extract desktop proxy, screenshot, cursor and portal configuration
  into focused modules so desktop/default.nix reads as composition plus packages.
- Keep cross-program integrations explicit; update relative paths and references
  when moving modules, scripts or assets.
- Preserve preferences in the literal home/variables.nix file. Do not add a
  parallel preference catalogue or change existing preference values.

## Ghostfolio removal

Remove the reusable module, host import and settings, system parameter fields
and example fields, parameter validation, generated command fixtures and checks.
Keep media-stack, AirVPN and proxy checks that remain relevant independently.
Update current documentation and TODO entries to remove obsolete Ghostfolio
instructions and requirements. Preserve unrelated content in mixed sections.
Do not delete databases, containers, secrets or any machine-local application
state. Removal affects source only until the user activates a later generation.

## Flake readability

After removing Ghostfolio, extract remaining check construction into
checks/default.nix with explicit inputs. Keep flake.nix focused on inputs,
parameter/context construction and exported configurations. Avoid introducing
frameworks or extra abstraction for host discovery.

## Compatibility and validation

All existing non-Ghostfolio behavior and enabled packages must remain intact.
The main checkout has unrelated changes to flake.lock and Yazi/program imports;
leave them untouched and account for their imports when integrating the branch.

Review moved files, import paths, package inventory and generated references.
Run git diff --check, parse every changed Nix file, run nix flake check
--no-build --show-trace, and evaluate both cf-fv1 system and lg@cf-fv1 Home
Manager derivation paths from the task worktree. Syntax-check changed scripts
if any. Do not update flake.lock, build or activate. Commit validated work,
merge while preserving unrelated changes, and push to the configured upstream.

## Presentation documentation

Document the ownership map and a short walkthrough: flake outputs, host
composition, category/default.nix, configured program module, editable
preference, evaluation, and generation/rollback concepts. Explain that system
and Home Manager activation are separate.
