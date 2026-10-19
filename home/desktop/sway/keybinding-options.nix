# Metadata travels with the command; Sway and the shortcut menu share it.
{ lib, ... }:
{
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
