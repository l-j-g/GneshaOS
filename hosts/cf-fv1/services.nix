{ pkgs, params, ... }:

{
  networking.hostName = params.systemSettings.hostName;
  networking.networkmanager.enable = true;

  # Local time = system timezone from the top-level params (should match the
  # wlsunset coordinates).
  time.timeZone = params.userSettings.timeZone;

  # macOS SMB share for the exFAT media volume.
  # Access is limited to the home LAN; authentication uses Samba's
  # separate password database for the user from the top-level params.
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = params.systemSettings.hostName;
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
        "valid users" = params.userSettings.userName;
        "force user" = params.userSettings.userName;
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
}
