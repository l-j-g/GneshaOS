{ params, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./laptop.nix
    ./services
    ./media.nix
    ./desktop.nix
    ./security.nix
    ../../modules/letsnote
    ../../modules/hardening.nix
    ../../modules/fonts.nix
    ../../modules/btrfs.nix
    ../../modules/airvpn-networkmanager.nix
  ];

  services.gnesha.airvpn = {
    enable = params.systemSettings.airVpn.enable or false;
    profilePath = params.systemSettings.airVpn.configPath or "/etc/airvpn/host.conf";
    autostart = params.systemSettings.airVpn.autostart or false;
    userName = params.userSettings.userName;
    homeDirectory = params.userSettings.homeDirectory;
  };

  system.stateVersion = "25.05";
}
