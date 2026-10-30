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
  rowsFor =
    mode: bindings:
    lib.mapAttrsToList (
      key: command:
      let
        changes = if mode == "default" then edits.keybindings else edits.modes.${mode} or { };
        original = lib.findFirst (name: changes.${name} == key) key (builtins.attrNames changes);
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
  capturePython = pkgs.python3.withPackages (p: [ p.pygobject3 ]);
  capture = pkgs.stdenvNoCC.mkDerivation {
    pname = "gnesha-capture-key";
    version = "1";
    dontUnpack = true;
    nativeBuildInputs = [
      pkgs.wrapGAppsHook4
      pkgs.gobject-introspection
    ];
    buildInputs = [
      pkgs.gtk4
      pkgs.gtk4-layer-shell
    ];
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      makeWrapper ${capturePython}/bin/python3 "$out/bin/gnesha-capture-key" \
        --add-flags ${./scripts/capture-key.py} \
        --prefix LD_PRELOAD : ${pkgs.gtk4-layer-shell}/lib/libgtk4-layer-shell.so
      runHook postInstall
    '';
  };
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
