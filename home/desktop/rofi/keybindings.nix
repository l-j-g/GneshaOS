# Searchable shortcut reference, generated from the effective Sway bindings.
{
  config,
  lib,
  pkgs,
  params,
  ...
}:
let
  sway = config.wayland.windowManager.sway.config;
  documented = config.gnesha.keybindings;
  edits = import ../sway/keybinding-edits.nix;
  # Index replacements once per mode so catalog rows can recover their source key.
  reverseKeys =
    changes:
    builtins.listToAttrs (
      lib.mapAttrsToList (name: value: {
        name = value;
        value = name;
      }) changes
    );
  originalKeys = reverseKeys edits.keybindings;
  originalModeKeys = lib.mapAttrs (_: reverseKeys) edits.modes;
  rowsFor =
    mode: bindings:
    lib.mapAttrsToList (
      key: command:
      let
        originals = if mode == "default" then originalKeys else originalModeKeys.${mode} or { };
        original = originals.${key} or key;
      in
      {
        inherit key command mode;
        sourceKey = original;
        # Only reuse metadata if it still describes the effective command.
        description =
          let
            binding = documented.${original} or null;
          in
          if mode == "default" && binding != null && binding.command == command then
            "${binding.category} // ${binding.description}"
          else
            command;
      }
    ) (lib.filterAttrs (_: command: command != null) bindings);
  capture = import ./capture-key.nix { inherit pkgs; };
  menuConfig = pkgs.writeText "gnesha-keybindings.json" (
    builtins.toJSON ({
      repo = params.systemSettings.flakePath;
      capture = "${capture}/bin/gnesha-capture-key";
      stateRoot = "${config.home.homeDirectory}/.local/state/gnesha-activation";
      catalog =
        rowsFor "default" sway.keybindings ++ lib.concatLists (lib.mapAttrsToList rowsFor sway.modes);
    })
  );
  menu = pkgs.writeShellApplication {
    name = "gnesha-keybindings";
    runtimeInputs = [
      pkgs.jq
      pkgs.gawk
      pkgs.nix
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      export PATH="${config.home.profileDirectory}/bin:/run/current-system/sw/bin:$PATH"
      set -- ${menuConfig} "$@"
    ''
    + builtins.readFile ./scripts/keybindings.sh;
  };
in
{
  home.packages = [ menu ];
  xdg.desktopEntries.gnesha-keybindings = {
    name = "Gnesha Keybindings";
    genericName = "Keyboard shortcuts";
    comment = "Search and edit Sway shortcuts and binding modes";
    exec = "${menu}/bin/gnesha-keybindings";
    icon = "preferences-desktop-keyboard-shortcuts";
    terminal = false;
    categories = [ "Settings" ];
  };
}
