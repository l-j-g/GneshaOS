# Desktop compositor stack. Sub-modules, one per concern:
#   sway.nix        - sway config + startup + modes (sway-extra.conf)
#   bindings.nix    - sway keybindings (imported by sway.nix)
#   waybar.nix      - top bar
#   foot.nix        - terminal
#   rofi.nix        - launcher
#   mako.nix        - notifications
#   swaylock.nix    - lock screen
#   daemons.nix     - swayidle, swayr, cliphist, foot-server, user services
#   scripts.nix     - vendored sway helper scripts + help overlay assets
#   vars.nix        - shared palette aliases (imported by the others)

{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./sway.nix
    ./waybar.nix
    ./foot.nix
    ./rofi.nix
    ./mako.nix
    ./swaylock.nix
    ./daemons.nix
    ./scripts.nix
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
    foot
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
    networkmanagerapplet
    blueman
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
