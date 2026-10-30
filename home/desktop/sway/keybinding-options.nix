# Metadata travels with the command; Sway and the shortcut menu share it.
{ lib, ... }:
{
  # Remap after merging so shortcuts contributed by other modules are included.
  # Applying this to the Sway config also covers native binding modes; commands
  # stay in their owning modules rather than being copied into an override list.
  options.wayland.windowManager.sway.config = lib.mkOption {
    apply = import ./keybinding-remap.nix {
      inherit lib;
      edits = import ./keybinding-edits.nix;
    };
  };

  options.gnesha.keybindings = lib.mkOption {
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          command = lib.mkOption { type = lib.types.str; };
          description = lib.mkOption { type = lib.types.str; };
          category = lib.mkOption { type = lib.types.str; };
        };
      }
    );
    description = "Default Sway shortcuts and their searchable help metadata.";
  };
}
