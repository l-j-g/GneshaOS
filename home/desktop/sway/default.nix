# Sway compositor layer: session configuration, bindings, lock screen,
# daemons, and helper scripts.

{
  imports = [
    ./sway.nix
    ./swaylock.nix
    ./daemons.nix
    ./scripts.nix
  ];
}
