{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.vim
    pkgs.git
    # Nix language tooling shared by editors and command-line clients.
    pkgs.nixd
    pkgs.nixfmt
    pkgs.curl
    pkgs.wget
    pkgs.file
    pkgs.pciutils
    pkgs.usbutils
    pkgs.libinput
    pkgs.rsync
    pkgs.gvfs
    pkgs.libmtp
    pkgs.udisks2
    pkgs.lm_sensors
    pkgs.nh
    pkgs.brightnessctl
    pkgs.acpi
    pkgs.powertop
    pkgs.docker-compose
    pkgs.libnotify
    # Ghostty sets TERM=xterm-ghostty; make that terminfo entry available
    # system-wide to tmux and programs launched outside Home Manager's shell.
    pkgs.ghostty.terminfo
  ];
}
