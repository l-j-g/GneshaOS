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

    # Legacy Compose path: its parent holds the arr .env and config directory.
    # Nix now generates the stack definition; manage it with the arr command.
    arrComposePath = "/home/lg/src/arr/docker-compose.yml";

    # Mount point of the MooGoo drive used for user media directories.
    mediaMountPoint = "/media";

    # HTTP/HTTPS proxy for compatible system applications. Start the Gluetun
    # proxy first (docs/airvpn-proxy.md). Set false to restore direct access.
    systemProxy = {
      enable = true;
      host = "127.0.0.1";
      port = 8888;
      noProxy = "localhost,127.0.0.1,::1,cf-fv1,.local";
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
