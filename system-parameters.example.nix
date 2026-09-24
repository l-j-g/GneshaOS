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

    # Runtime Compose state and credentials live outside the Nix store.
    containersDirectory = "/home/your-user/.config/containers";
    arrComposePath = "/home/your-user/.config/containers/arr/compose.yml";
    ghostfolioPostgresMajor = "17";

    # Mount point of the media drive used for user media directories.
    mediaMountPoint = "/media";

    # Optional independent host HTTP proxy. Leave disabled for native WireGuard.
    # Never point this at Docker Gluetun; see docs/airvpn-proxy.md.
    systemProxy = {
      enable = false;
      host = "127.0.0.1";
      port = 8888;
      noProxy = "localhost,127.0.0.1,::1,cf-fv1,.local";
    };

    # Docker-only HTTP CONNECT proxy; never sets host proxy variables.
    dockerProxy = {
      enable = false;
      port = 8888;
      noProxy = "localhost,127.0.0.1,::1,cf-fv1,.local";
    };

    # System-wide AirVPN WireGuard tunnel. Install the private profile manually
    # at the configured path as a root-owned mode-600 file. Choose the path
    # here in system-parameters.nix; never commit the profile or put it in the
    # Nix store. The tunnel starts only on request, never at boot.
    airVpn = {
      enable = false;
      configPath = "/path/to/root-owned/airvpn-profile.conf";
    };
  };

  userSettings = {
    # POSIX login name. Must match the user declared by the host module.
    userName = "lg";

    # Home directory. Must match the user's system account and @home volume.
    homeDirectory = "/home/lg";
  };
}
