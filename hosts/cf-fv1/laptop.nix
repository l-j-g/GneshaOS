{ pkgs, ... }:

{
  # hardware.enableAllFirmware (in hardware-configuration.nix) includes
  # unfree firmware (e.g. broadcom-bt-firmware). Allow it for this laptop.
  nixpkgs.config.allowUnfree = true;

  hardware.cpu.intel.updateMicrocode = true;

  # Iris Xe iGPU + VA-API video decode
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ intel-media-driver ];
  };

  # Let's Note specific kernel bits (ec charge limit, hotkeys, backlight)
  # IIO ambient light sensor -> iio-sensor-proxy (auto-brightness)
  hardware.sensor.iio.enable = true;

  letsnote.ecFeatures = true;
  # CPU power capping (RAPL): 20W sustained on AC, 15W on battery.
  # The CF-FV1 does not have general fan-speed control here; the separate
  # fanControl option only requests its EC quiet profile. CPU power capping is
  # the other heat/noise control.
  letsnote.cpuPower = true;
  # Keep the firmware default: SEFM 0x01 reduced noise but caused
  # prolonged fan-off periods followed by brief fan bursts on this CF-FV1.
  letsnote.fanControl = false;
  # Remap the dead JIS keys (無変換/変換/かな) to something useful
  letsnote.jisKeys = true;

  powerManagement.enable = true;
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
  services.fwupd.enable = true;
  # Sway owns battery lid-close suspend after locker readiness; logind only
  # requests a lock so it cannot bypass that gate. AC/docked closure lock only.
  services.logind.settings.Login = {
    HandleLidSwitch = "lock";
    HandleLidSwitchExternalPower = "lock";
    HandleLidSwitchDocked = "lock";
  };
  zramSwap.enable = true;
  zramSwap.memoryPercent = 50;
}
