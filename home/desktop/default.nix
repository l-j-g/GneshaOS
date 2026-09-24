# Desktop compositor stack. Sub-modules, one per concern:
#   waybar.nix      - top bar
#   rofi.nix        - launcher
#   mako.nix        - notifications
#   sway/           - Sway compositor, lock screen, daemons, bindings, scripts
#   theme/palette.nix - shared palette aliases (imported by the others)
# Terminal programs live under programs/terminals.

{
  pkgs,
  lib,
  params,
  ...
}:

let
  proxy = params.systemSettings.systemProxy or { enable = false; };
in
{
  imports = [
    ./sway
    ./waybar.nix
    ./rofi.nix
    ./mako.nix
  ];

  # Use Home Manager's packaged SwayOSD service for volume/backlight OSDs.
  services.swayosd.enable = true;

  # Standard desktop proxy settings, also used by browsers in system mode.
  dconf.settings = {
    "org/gnome/system/proxy" = {
      mode = if proxy.enable then "manual" else "none";
    } // lib.optionalAttrs proxy.enable {
      use-same-proxy = false;
      ignore-hosts = map
        (host: if lib.hasPrefix "." host then "*${host}" else host)
        (lib.splitString "," proxy.noProxy);
    };
  } // lib.optionalAttrs proxy.enable {
    "org/gnome/system/proxy/http" = {
      host = proxy.host;
      port = proxy.port;
    };
    "org/gnome/system/proxy/https" = {
      host = proxy.host;
      port = proxy.port;
    };
  };

  # Firefox runs natively on Wayland (not XWayland) so Sway's `scale 2`
  # isn't applied twice -> no blurry/oversized UI.
  home.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
    MOZ_WAYLAND_USE_FLOAT_SCALE = "1";
  };

  # exFAT rejects ':' in filenames, while grimshot's default `date -Ins`
  # timestamp includes colons. Put a safe wrapper earlier in PATH so all
  # existing Sway screenshot bindings continue to work on the media drive.
  home.file.".local/bin/grimshot" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      set -eu
      if [ -z "''${GRIMSHOT_FILENAME_FORMAT:-}" ]; then
        export GRIMSHOT_FILENAME_FORMAT="$(${pkgs.coreutils}/bin/date +%Y-%m-%dT%H-%M-%S-%N)"
      fi
      exec ${pkgs.sway-contrib.grimshot}/bin/grimshot "$@"
    '';
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
