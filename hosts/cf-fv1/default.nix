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
  ];

  system.stateVersion = "25.05";
}
