{
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./laptop.nix
    ./services.nix
    ./media.nix
    ./desktop.nix
    ./security.nix
    ../../modules/letsnote
    ../../modules/hardening.nix
    ../../modules/fonts.nix
    ../../modules/btrfs.nix
    # ../../modules/ghostfolio.nix
    ../../modules/airvpn-wireguard.nix
  ];

  system.stateVersion = "25.05";
}
