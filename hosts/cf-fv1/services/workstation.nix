{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    vim
    git
    # Nix language tooling shared by editors and command-line clients.
    nixd
    nixfmt
    curl
    wget
    file
    pciutils
    usbutils
    libinput
    rsync
    gvfs
    libmtp
    udisks2
    lm_sensors
    nh
    brightnessctl
    acpi
    powertop
    docker-compose
    libnotify
    # Ghostty sets TERM=xterm-ghostty; make that terminfo entry available
    # system-wide to tmux and programs launched outside Home Manager's shell.
    ghostty.terminfo
  ];
}
