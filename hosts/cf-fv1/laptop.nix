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
  # Request the CF-FV1 EC quiet profile via acpi_call (SEFM eco). The ACPI
  # method result does not confirm that the EC applied the requested mode.
  letsnote.fanControl = true;
  # Remap the dead JIS keys (無変換/変換/かな) to something useful
  letsnote.jisKeys = true;

  powerManagement.enable = true;
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
  services.fwupd.enable = true;
  # Keep services running on AC, but request a session lock on lid closure.
  # Sway also handles the lid switch so this works with external displays.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "lock";
    HandleLidSwitchDocked = "lock";
  };
  zramSwap.enable = true;
  zramSwap.memoryPercent = 50;
}
