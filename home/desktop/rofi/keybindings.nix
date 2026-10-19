# Searchable shortcut reference, generated from the effective Sway bindings.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  sway = config.wayland.windowManager.sway.config;
  documented = config.gnesha.keybindings;
  rowsFor =
    mode: bindings:
    lib.mapAttrsToList (key: command: {
      inherit key command mode;
      # Only reuse metadata if it still describes the effective command.
      description =
        let
          binding = documented.${key} or null;
        in
        if mode == "default" && binding != null && binding.command == command then
          "${binding.category} // ${binding.description}"
        else
          command;
    }) (lib.filterAttrs (_: command: command != null) bindings);
  catalog = pkgs.writeText "gnesha-keybindings.json" (
    builtins.toJSON (
      rowsFor "default" sway.keybindings ++ lib.concatLists (lib.mapAttrsToList rowsFor sway.modes)
    )
  );
  menu = pkgs.writeShellApplication {
    name = "gnesha-keybindings";
    runtimeInputs = [
      pkgs.jq
      pkgs.gawk
    ];
    text = ''
      export PATH="${config.home.profileDirectory}/bin:/run/current-system/sw/bin:$PATH"
      set -- ${catalog} "$@"
    ''
    + builtins.readFile ./scripts/keybindings.sh;
  };
in
{
  home.packages = [ menu ];
  xdg.desktopEntries.gnesha-keybindings = {
    name = "Gnesha Keybindings";
    genericName = "Keyboard shortcut reference";
    comment = "Search Sway shortcuts and binding modes";
    exec = "${menu}/bin/gnesha-keybindings";
    icon = "preferences-desktop-keyboard-shortcuts";
    terminal = false;
    categories = [ "Settings" ];
  };
}
