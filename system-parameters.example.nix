# GneshaOS stable system parameters (template / fallback).
#
# Copy this file to system-parameters.nix and edit the values for your
# machine. The editable Home Manager preferences live in home/variables.nix.
# The flake uses this file as a fallback when system-parameters.nix is absent.
#
# Host-specific stable overrides can be added in
# hosts/<host>/system-parameters.nix.
{
  systemSettings = {
    # Compatibility/default reference. The host directory name is authoritative
    # for the flake output and is overlaid into each discovered host's params.
    hostName = "cf-fv1";

    # Absolute path of this flake directory on your machine. Used by the shell
    # rebuild/check helpers. Default: /etc/nixos.
    flakePath = "/etc/nixos";

    # IANA timezone used by the NixOS system.
    timeZone = "Australia/Sydney";

    # Geographic coordinates used by wlsunset. South and west are negative.
    latitude = -33.87;
    longitude = 151.21;

    # Native panel resolution in pixels, used for generated wallpaper sizing.
    displayWidth = 2160;
    displayHeight = 1440;

    # Keyboard layout and option remaps applied by Sway.
    keyboardLayout = "us";
    keyboardOptions = "ctrl:nocaps";

    # Hardware-specific identifiers. Check the target machine with
    # `brightnessctl -l` and by inspecting /sys/bus/iio/devices/.
    backlightDevice = "intel_backlight";
    alsSensorPath = "/sys/bus/iio/devices/iio:device5/in_illuminance_raw";

    # Legacy Compose path: its parent holds the arr .env and config directory.
    # Nix now generates the stack definition; manage it with the arr command.
    arrComposePath = "/home/lg/src/arr/docker-compose.yml";

    # Mount point of the media drive used for user media directories.
    mediaMountPoint = "/media";

    # Optional local HTTP/HTTPS proxy; start it before enabling these settings.
    # See docs/airvpn-proxy.md for Gluetun setup and verification.
    systemProxy = {
      enable = false;
      host = "127.0.0.1";
      port = 8888;
      noProxy = "localhost,127.0.0.1,::1,cf-fv1,.local";
    };
  };

  userSettings = {
    # POSIX login name. Must match the user declared by the host module.
    userName = "lg";

    # Home directory. Must match the user's system account and @home volume.
    homeDirectory = "/home/lg";
  };
}
