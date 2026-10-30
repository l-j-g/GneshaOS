# Sway compositor layer: session configuration, bindings, lock screen,
# daemons, and helper scripts.

{
  imports = [
    ./sway.nix
    ./keybinding-options.nix
    ./swaylock.nix
    ./displays.nix
    ./daemons.nix
    ./scripts.nix
    ./dictation.nix
  ];
}
