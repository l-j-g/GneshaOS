# Apply key changes after Home Manager has merged the native Sway options.
{ lib, edits }:
config:
let
  rename =
    bindings: changes:
    let
      renamed = lib.mapAttrsToList (key: command: {
        name = changes.${key} or key;
        value = command;
      }) bindings;
      names = map (binding: binding.name) renamed;
    in
    assert lib.assertMsg (builtins.all (key: builtins.hasAttr key bindings) (
      builtins.attrNames changes
    )) "A saved shortcut no longer exists; remove its entry from keybinding-edits.nix";
    assert lib.assertMsg (
      builtins.length names == builtins.length (lib.unique names)
    ) "Saved Sway shortcuts conflict; check keybinding-edits.nix";
    builtins.listToAttrs renamed;
in
if config == null then
  null
else
  config
  // {
    keybindings = rename config.keybindings edits.keybindings;
    # Keep validation local: mode defaults refer back to config.left/right.
    # Forcing modes while evaluating those fields would recurse.
    modes =
      assert lib.assertMsg (builtins.all (mode: builtins.hasAttr mode config.modes) (
        builtins.attrNames edits.modes
      )) "A saved shortcut mode no longer exists; remove its entry from keybinding-edits.nix";
      lib.mapAttrs (mode: bindings: rename bindings (edits.modes.${mode} or { })) config.modes;
  }
