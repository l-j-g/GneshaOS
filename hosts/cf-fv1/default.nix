{
  config,
  pkgs,
  lib,
  username,
  ...
}:

{
  # hardware.enableAllFirmware (in hardware-configuration.nix) includes
  # unfree firmware (e.g. broadcom-bt-firmware). Allow it for this laptop.
  nixpkgs.config.allowUnfree = true;

  imports = [
    ./hardware-configuration.nix
    ../../modules/letsnote
    ../../modules/hardening.nix
    ../../modules/fonts.nix
    ../../modules/btrfs.nix
  ];

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

  networking.hostName = "cf-fv1";
  networking.networkmanager.enable = true;

  # Make dconf/gsettings available so home-manager can apply the GTK theme
  # (home-manager writes the theme/icon to org/gnome/desktop/interface).
  programs.dconf.enable = true;

  # Local time = Australia/Sydney (matches the wlsunset coordinates).
  time.timeZone = "Australia/Sydney";

  # macOS SMB share for the exFAT media volume.
  # Access is limited to the home LAN; authentication uses Samba's
  # separate password database for user lg.
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = "cf-fv1";
        security = "user";
        "map to guest" = "never";
        "server min protocol" = "SMB2";
        # SMB is LAN-only: set "hosts allow" to your subnet + loopback,
        # and deny everything else.
        "hosts allow" = "127.";
        "hosts deny" = "0.0.0.0/0";
      };
      media = {
        path = "/media";
        browseable = "yes";
        "read only" = "no";
        "valid users" = "lg";
        "force user" = "lg";
        "create mask" = "0664";
        "directory mask" = "0775";
      };
    };
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd sway";
      user = "greeter";
    };
  };

  hardware.bluetooth.enable = true;

  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  services.libinput.enable = true;

  # Make login shell (fish) available system-wide and link portal files
  # when Home Manager runs with useUserPackages.
  programs.fish.enable = true;
  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];

  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    file
    pciutils
    usbutils
    libinput
    rsync
    gvfs
    libmtp
    udisks2
    lm_sensors
    brightnessctl
    acpi
    powertop
    docker-compose
    ghostty
    libnotify
  ];

  # Docker engine + compose for the self-hosted media stack (Lidarr/Prowlarr/etc.)
  virtualisation.docker.enable = true;
  virtualisation.docker.autoPrune = {
    enable = true;
    dates = "weekly";
  };
  # Let lg run docker without sudo and manage the stack
  users.users.lg.extraGroups = [
    "docker"
    "input"
  ];

  # Stop Docker *arr stack before /media unmounts (containers hold volumes).
  systemd.services.docker-compose-stop = {
    description = "Stop Docker *arr stack before /media unmount";
    wantedBy = [ "multi-user.target" ];
    before = [ "shutdown.target" ];
    requires = [ "docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
      ExecStop = "${pkgs.docker}/bin/docker compose -f /home/lg/src/arr/docker-compose.yml down";
      TimeoutStopSec = 60;
    };
  };

  # Private mesh VPN for reaching self-hosted services from any device anywhere
  services.tailscale.enable = true;
  services.gvfs.enable = true;

  # Cache sudo credentials for 30 minutes instead of the default 5.
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=30
  '';

  system.stateVersion = "25.05";
}
