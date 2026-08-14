# THIS FILE IS GENERATED ON THE TARGET MACHINE
#
# Run on the installer (replace /mnt with your mount point):
#   nixos-generate-config --root /mnt
# then copy the generated file here and adjust. This template matches the
# plan in docs/install.md: btrfs subvolumes inside a LUKS2 volume
# (TPM2 auto-unlock) + an exFAT media partition.

{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "sd_mod"
    "tpm"
  ];
  boot.initrd.kernelModules = [ "dm_mod" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # LUKS2 root, auto-unlocked by the firmware TPM (Intel PTT) at boot.
  # systemd-cryptenroll is run once after install; see the runbook.
  boot.initrd.systemd.enable = true;
  boot.initrd.luks.devices."root" = {
    device = "/dev/disk/by-uuid/48440b50-145c-43c5-902c-636e625c1d59";
    crypttabExtraOpts = [ "tpm2-device=auto" ];
  };

  fileSystems."/" = {
    device = "/dev/mapper/root";
    fsType = "btrfs";
    options = [
      "subvol=@"
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/mapper/root";
    fsType = "btrfs";
    options = [
      "subvol=@nix"
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/mapper/root";
    fsType = "btrfs";
    options = [
      "subvol=@home"
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/B597-4003";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  # Media drive -> mounted at /media, exposed at ~/media.
  # exFAT for now (btrfs conversion blocked by a persistent kernel "busy" on the drive).
  # nofail: a failed mount must NOT drop the system into emergency mode.
  fileSystems."/media" = {
    device = "/dev/disk/by-uuid/EEF9-FBCB";
    fsType = "exfat";
    # uid/gid make the whole drive owned by lg:users so containers (PUID 1000) can write
    options = [
      "noatime"
      "nofail"
      "uid=1000"
      "gid=100"
      "umask=022"
    ];
  };

  swapDevices = [ ]; # zram is used instead (zramSwap.memoryPercent = 50)

  # 11th gen Intel (Tiger Lake)
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.enableAllFirmware = true;
}
