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
  # Fans are EC-managed and not software-controllable on CF-FV1 (panafanpwr
  # doesn't support this model) - the power cap is the heat/noise lever.
  letsnote.cpuPower = true;
  # EC quiet fan curve via acpi_call (SEFM eco); verified on-device.
  letsnote.fanControl = true;
  # Remap the dead JIS keys (無変換/変換/かな) to something useful
  letsnote.jisKeys = true;

  powerManagement.enable = true;
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
  services.fwupd.enable = true;
  # Don't suspend when on AC power: closing the lid while plugged in just
  # turns off the display instead of sleeping the machine.
  services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";
  zramSwap.enable = true;
  zramSwap.memoryPercent = 50;
}
