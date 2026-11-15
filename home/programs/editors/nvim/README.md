# Neovim base and personal settings

The `neovim-config` flake input supplies the configured editor from
`alinabi/neovim-nixos-config`. Its own lockfile pins its compatible Neovim,
Nixpkgs and plugin versions; it deliberately does not follow system Nixpkgs.

The integration recovers the base's original modules and invokes its module
builder directly. The pinned upstream's `extendConfiguration` has a wrong
relative import, and its passthru shadows the module metadata; the small
adapter in `default.nix` works around both without changing upstream files.

`personal.nix` extends the base, enables the vi alias and arrow navigation,
and includes every Treesitter grammar supplied by the base's pinned Nixpkgs.
It applies `lua/gnesha/options.lua` and `lua/gnesha/keymaps.lua` last, keeping
personal options and Alt-h/j/k/l window navigation ahead of upstream mappings.
Nix buffers also keep your four-space indentation preference.
Edit these two Lua files for everyday customization.

The previous `init.lua` and other `lua/gnesha` modules remain as reference;
they are not loaded. Upstream owns plugins, completion, LSP and its theme.
The old nixd option helpers and live Gnesha theme integration are therefore
not active in this setup.

## Updates

- `rebuild` uses the current `flake.lock`.
- `rebuild-update` updates all top-level flake inputs, then uses the same
  frozen-snapshot NixOS/Home Manager build and activation workflow.
- The existing background lock refresh also includes `neovim-config`.

Input updates use Nix's normal revision/fetch output. Build phases use the
existing nix-output-monitor helper. Updating happens under the activation
lock, before the snapshot is frozen. An update failure stops the command;
a build failure prevents activation and leaves the new lockfile for retry.

Updating the base receives the maintainer's pinned plugin revisions; it does
not independently advance every plugin. Upstream API changes may require
adjusting `personal.nix`. Updating and rebuilding are separate from committing
changes to `flake.lock`.
