# Check remapping against the pinned library without activating Sway.
{ lib }:
let
  base = {
    keybindings = {
      "Mod4+a" = "exec /nix/store/current-version/bin/app";
      "--release Ctrl+0" = "exec show-size";
      "Mod4+b" = "exec beta";
    };
    modes.resize = {
      Left = "resize shrink width 10 px";
      Escape = "mode default";
    };
  };
  apply = edits: import ../home/desktop/sway/keybinding-remap.nix { inherit lib edits; } base;
  result = apply {
    keybindings = {
      "Mod4+a" = "Mod4+x";
    };
    modes.resize = {
      Left = "h";
    };
  };
  # Home Manager's mode defaults interpolate fields from the same config.
  # The remapper must not force modes while evaluating those fields.
  recursive = lib.fix (
    self:
    import ../home/desktop/sway/keybinding-remap.nix
      {
        inherit lib;
        edits = {
          keybindings = { };
          modes.resize = {
            h = "F11";
          };
        };
      }
      {
        left = "h";
        keybindings = {
          "Mod4+${self.left}" = "focus left";
        };
        modes.resize = {
          "${self.left}" = "resize shrink width 10 px";
        };
      }
  );
  collision = builtins.tryEval (
    builtins.deepSeq (apply {
      keybindings = {
        "Mod4+a" = "Mod4+b";
      };
      modes = { };
    }) true
  );
  removed = builtins.tryEval (
    builtins.deepSeq (apply {
      keybindings = {
        "Mod4+missing" = "Mod4+x";
      };
      modes = { };
    }) true
  );
in
assert
  result.keybindings == {
    "Mod4+x" = "exec /nix/store/current-version/bin/app";
    "--release Ctrl+0" = "exec show-size";
    "Mod4+b" = "exec beta";
  };
assert
  result.modes.resize == {
    h = "resize shrink width 10 px";
    Escape = "mode default";
  };
assert !collision.success;
assert !removed.success;
assert recursive.keybindings."Mod4+h" == "focus left";
assert recursive.modes.resize.F11 == "resize shrink width 10 px";
true
