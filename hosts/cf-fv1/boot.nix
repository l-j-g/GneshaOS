{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Skip the boot-menu wait -> login ASAP (hold a key to still open it)
  boot.loader.timeout = 1;

  # Don't block login waiting for the network to come up
  systemd.services.NetworkManager-wait-online.enable = false;

  # Faster service timeouts (no long waits on slow units).
  # LogLevel=warning silences systemd's "Starting/Started container..." lines.
  systemd.settings.Manager = {
    DefaultTimeoutStartSec = "5s";
    DefaultTimeoutStopSec = "10s";
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
