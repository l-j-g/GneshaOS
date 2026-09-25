{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Skip the boot-menu wait -> login ASAP (hold a key to still open it)
  boot.loader.timeout = 1;

  # Keep login independent of connectivity. network-online.target below is
  # only an ordering point because this wait service is disabled.
  systemd.services.NetworkManager-wait-online.enable = false;

  # Keep systemd's normal bounded service deadlines.
  # LogLevel=warning silences systemd's "Starting/Started container..." lines.
  systemd.settings.Manager = {
    DefaultTimeoutStartSec = "90s";
    DefaultTimeoutStopSec = "90s";
    LogLevel = "warning";
  };

  # Quiet boot: hide kernel/systemd diagnostics from the console.
  boot.kernelParams = [
    "quiet"
    "nowatchdog"
  ];
  boot.consoleLogLevel = 3;

  # Tiger Lake - load the latest kernel if stock unstable kernel lags
  # boot.kernelPackages = pkgs.linuxPackages_latest;
}
