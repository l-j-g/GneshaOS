# Desktop compositor stack. Sub-modules, one per concern:
#   waybar.nix      - top bar
#   rofi.nix        - launcher
#   mako.nix        - notifications
#   sway/           - Sway compositor, lock screen, daemons, bindings, scripts
#   theme/palette.nix - shared palette aliases (imported by the others)
# Terminal programs live under programs/terminals.

{
  pkgs,
  ...
}:

{
  imports = [
    ./sway
    ./waybar.nix
    ./rofi.nix
    ./mako.nix
  ];

  # Use Home Manager's packaged SwayOSD service for volume/backlight OSDs.
  services.swayosd.enable = true;

  # Firefox runs natively on Wayland (not XWayland) so Sway's `scale 2`
  # isn't applied twice -> no blurry/oversized UI.
  home.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
    MOZ_WAYLAND_USE_FLOAT_SCALE = "1";
  };

  home.pointerCursor = {
    enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 32;
  };

  home.packages = with pkgs; [
    waybar
    mako
    swaylock
    swayidle
    wl-clipboard
    grim
    slurp
    wlsunset
    brightnessctl
    playerctl
    pavucontrol
    vlc
    way-displays
    bluetuith
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr

    # Manjaro Sway alignment
    rofi
    swayest-workstyle
    flashfocus
    wl-clip-persist
    calcurse
    dex
    polkit_gnome
    noisetorch
    nwg-wrapper
    autotiling
    acpi
    wf-recorder
    swappy
    sway-contrib.grimshot
    emoji-picker
    bc
    python3
  ];

  xdg.portal = {
    enable = true;
    config.common.default = "gtk";
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-wlr
    ];
  };
}
