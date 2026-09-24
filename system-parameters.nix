# GneshaOS stable system parameters.
#
# These values identify or operate the machine and are not expected to change
# during normal desktop customization. Editable Home Manager preferences live
# in home/variables.nix.
{
  systemSettings = {
    # Machine hostname. The discovered host directory is authoritative for
    # flake output names, but this remains the default/reference value.
    hostName = "cf-fv1";

    # Absolute path of this flake on the machine. Used by rebuild and checking
    # helpers. This is normally /etc/nixos on the installed system.
    flakePath = "/etc/nixos";

    # IANA timezone used by the NixOS system.
    timeZone = "Australia/Sydney";

    # Geographic coordinates used by wlsunset. South and west are negative.
    latitude = -33.87;
    longitude = 151.21;

    # Native panel resolution used when generating wallpaper SVGs.
    displayWidth = 2160;
    displayHeight = 1440;

    # Keyboard layout and option remaps applied by Sway.
    keyboardLayout = "us";
    keyboardOptions = "ctrl:nocaps";

    # Hardware-specific backlight and ambient-light sensor identifiers.
    backlightDevice = "intel_backlight";
    alsSensorPath = "/sys/bus/iio/devices/iio:device5/in_illuminance_raw";

    # Runtime Compose state and credentials live outside the Nix store.
    containersDirectory = "/home/lg/.config/containers";
    arrComposePath = "/home/lg/src/arr/docker-compose.yml";
    # Match this to the current native PostgreSQL major version before import.
    ghostfolioPostgresMajor = "17";

    # Mount point of the MooGoo drive used for user media directories.
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
      enable = true;
      port = 8888;
      noProxy = "localhost,127.0.0.1,::1,cf-fv1,.local";
    };

    # System-wide AirVPN WireGuard tunnel. configPath is user-editable; install
    # the private profile there as root-owned mode 600. Keep it outside the repo
    # and Nix store. The tunnel starts only on request, never at boot.
    airVpn = {
      # Temporary nz.conf profile; use a separate device key for concurrent tunnels.
      enable = true;
      configPath = "/etc/airvpn/host.conf";
    };
  };

  userSettings = {
    # POSIX login name used by NixOS users, Home Manager, Samba, and Docker.
    userName = "lg";

    # Home directory. This must match the user's system account and @home
    # subvolume location.
    homeDirectory = "/home/lg";
  };
}
