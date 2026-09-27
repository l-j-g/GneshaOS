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
    ../../modules/ghostfolio.nix
    ../../modules/airvpn-networkmanager.nix
  ];

  services.gnesha.airvpn = {
    enable = params.systemSettings.airVpn.enable or false;
    profilePath = params.systemSettings.airVpn.configPath or "/etc/airvpn/host.conf";
    autostart = params.systemSettings.airVpn.autostart or false;
    userName = params.userSettings.userName;
    homeDirectory = params.userSettings.homeDirectory;
  };

  services.gnesha.ghostfolio = {
    enable = params.systemSettings.ghostfolio.enable or false;
    runtimeDirectory = "${params.systemSettings.containersDirectory}/ghostfolio";
    secretsFile = params.systemSettings.ghostfolio.secretsFile or "/etc/ghostfolio/secrets.env";
    postgresMajor = params.systemSettings.ghostfolioPostgresMajor or "17";
    proxy = params.systemSettings.dockerProxy or { enable = false; };
  };

  system.stateVersion = "25.05";
}
