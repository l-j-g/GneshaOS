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
    lib.mapAttrsToList (
      key: command:
      let
        binding = documented.${key} or null;
        hasMetadata = mode == "default" && binding != null && binding.command == command;
      in
      {
        inherit key command mode;
        category =
          if hasMetadata then
            binding.category
          else if mode == "default" then
            "Sway"
          else
            mode;
        description = if hasMetadata then binding.description else command;
      }
    ) (lib.filterAttrs (_: command: command != null) bindings);
  menuConfig = pkgs.writeText "gnesha-keybindings.json" (
    builtins.toJSON {
      catalog =
        rowsFor "default" sway.keybindings ++ lib.concatLists (lib.mapAttrsToList rowsFor sway.modes);
    }
  );
  menu = pkgs.writeShellApplication {
    name = "gnesha-keybindings";
    runtimeInputs = [
      pkgs.jq
      pkgs.gawk
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
    comment = "Search Sway shortcuts and binding modes";
    exec = "${menu}/bin/gnesha-keybindings";
    icon = "preferences-desktop-keyboard-shortcuts";
    terminal = false;
    categories = [ "Settings" ];
  };
}
