# GneshaOS top-level parameters.
#
# This is the ONE file you edit to make the config yours: username, hostname,
# display resolution/scaling, keyboard layout, timezone, paths, preferences.
# Every other .nix file reads from here — nothing user-specific is hardcoded
# anywhere else (except hardware-configuration.nix, which is machine-generated).
#
# New user? Copy params.example.nix to params.nix (or just edit this file —
# it is tracked by design so `nix flake` sees it) and change what you need.
# Each field is documented in params.example.nix; values below are the
# reference machine's (cf-fv1 / lg).
{
  # Machine-level settings (what host this config builds for).
  systemSettings = {
    # Machine hostname. Must match `networking.hostName` users expect and is
    # the `nixos-rebuild --flake .#<host>` attribute name.
    hostName = "cf-fv1";

    # Absolute path of this flake on the machine. Used by the rebuild/nixcheck
    # shell aliases and the als-brightness systemd unit. Default /etc/nixos.
    flakePath = "/etc/nixos";
  };

  # User-level settings (who sits at the machine, and their preferences).
  userSettings = {
    # POSIX login name. Threaded into NixOS users, home-manager, samba, docker.
    userName = "lg";

    # Git identity (commits you make).
    gitUserName = "lg";
    gitUserEmail = "lg@lgreve.com";

    # Home directory (must match the @home subvolume / useradd default).
    homeDirectory = "/home/lg";

    # Location: system timezone + wlsunset sun-position coordinates
    # (lat/lon in decimal degrees, negative = south/west).
    timeZone = "Australia/Sydney";
    latitude = -33.87;
    longitude = 151.21;

    # Keyboard layout (xkb_layout / xkb_options in sway).
    keyboardLayout = "us";
    keyboardOptions = "ctrl:nocaps";

    # Display panel: native resolution in px (drives the generated wallpaper
    # SVG) and sway scaling factor (2 = 200% HiDPI).
    displayWidth = 2160;
    displayHeight = 1440;
    displayScale = "2";

    # Desktop preferences.
    gapsInner = 5; # sway gaps inner (px)
    gapsOuter = 5; # sway gaps outer (px)
    terminalFontSize = 11; # foot font size (pt)
    screenshotDir = "~/Pictures/Screenshots"; # where grimshot screenshots land
    screenshotUploadUrl = "https://x0.at/"; # anonymous image host for screenshot upload

    # Idle timeouts (seconds) + dim level (%) for swayidle.
    idleDimSec = 240;
    idleDimPercent = 10;
    idleLockSec = 300;
    idleOffSec = 600;
    idleSuspendSec = 900;

    # Hardware device names (OS-specific: check `brightnessctl -l` /
    # `/sys/class/backlight/*` and your IIO sensor under
    # /sys/bus/iio/devices/ on the target machine).
    backlightDevice = "intel_backlight";
    alsSensorPath = "/sys/bus/iio/devices/iio:device4/in_illuminance_raw";

    # Absolute path to the docker-compose file of the self-hosted media stack
    # (stopped before /media unmounts at shutdown).
    arrComposePath = "/home/lg/src/arr/docker-compose.yml";
  };
}
