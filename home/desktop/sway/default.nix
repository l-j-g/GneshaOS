# Sway compositor layer: session configuration, bindings, lock screen,
# daemons, and helper scripts.

{
  imports = [
    ./sway.nix
    ./keybindings.nix
    ./swaylock.nix
    ./daemons.nix
    ./scripts.nix
    ./dictation.nix
  ];
}
