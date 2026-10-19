# Desktop composition: configured components below, standalone packages here.
# Application configuration lives in home/programs; shared colors in home/theme.
{ pkgs, ... }:

{
  imports = [
    ./sway
    ./waybar.nix
    ./rofi
    ./mako.nix
    ./proxy.nix
    ./grimshot.nix
    ./cursor.nix
    ./portals.nix
  ];

  # No custom configuration needed for volume/backlight notifications.
  services.swayosd.enable = true;

  home.packages = [
    pkgs.waybar
    pkgs.mako
    pkgs.swaylock
    pkgs.swayidle
    pkgs.wl-clipboard
    pkgs.grim
    pkgs.slurp
    pkgs.wlsunset
    pkgs.brightnessctl
    pkgs.playerctl
    pkgs.pavucontrol
    pkgs.vlc
    pkgs.way-displays
    pkgs.bluetuith
    pkgs.xdg-desktop-portal-gtk
    pkgs.xdg-desktop-portal-wlr

    # Manjaro Sway alignment
    pkgs.rofi
    pkgs.flashfocus
    pkgs.wl-clip-persist
    pkgs.calcurse
    pkgs.dex
    pkgs.polkit_gnome
    pkgs.noisetorch
    pkgs.acpi
    pkgs.wf-recorder
    pkgs.swappy
    pkgs.sway-contrib.grimshot
    pkgs.emoji-picker
    pkgs.bc
    pkgs.python3
  ];
}
