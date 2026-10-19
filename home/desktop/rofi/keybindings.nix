# Searchable shortcut reference, generated from the effective Sway bindings.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  sway = config.wayland.windowManager.sway.config;
  # Reuse the comments beside the bindings rather than maintaining a help list.
  documented =
    builtins.foldl'
      (
        state: line:
        let
          comment = builtins.match "[[:space:]]*# (.*)" line;
          binding = builtins.match ''[[:space:]]*"([^"]+)" = .*'' line;
        in
        if comment != null then
          state // { description = builtins.head comment; }
        else if binding != null then
          state
          // {
            labels = state.labels // {
              ${lib.replaceStrings [ "\${m}" ] [ sway.modifier ] (builtins.head binding)} = state.description;
            };
          }
        else
          state
      )
      {
        description = "";
        labels = { };
      }
      (lib.splitString "\n" (builtins.readFile ../sway/bindings.nix));
  rowsFor =
    mode: bindings:
    lib.mapAttrsToList (key: command: {
      inherit key command mode;
      description = if mode == "default" then documented.labels.${key} or command else command;
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
