# btrfs maintenance: snapper snapshots + timeline for the @ and @home
# subvolumes, plus monthly scrub.
#
# Requires the btrfs root layout from docs/install.md. During
# install, the .snapshots subvolumes must be created (see runbook step 6):
#   btrfs subvolume create /mnt/@/.snapshots
#   btrfs subvolume create /mnt/@home/.snapshots

{
  config,
  pkgs,
  lib,
  username,
  ...
}:

{
  services.btrfs.autoScrub.enable = true;

  services.snapper = {
    persistentTimer = true;

    # Snapshot the root subvolume on every boot as an extra safety net.
    snapshotRootOnBoot = true;

    configs = {
      root = {
        SUBVOLUME = "/";
        FSTYPE = "btrfs";
        ALLOW_USERS = [ username ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = 8;
        TIMELINE_LIMIT_DAILY = 7;
        TIMELINE_LIMIT_WEEKLY = 4;
        TIMELINE_LIMIT_MONTHLY = 2;
        TIMELINE_LIMIT_YEARLY = 0;
      };
      home = {
        SUBVOLUME = "/home";
        FSTYPE = "btrfs";
        ALLOW_USERS = [ username ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = 8;
        TIMELINE_LIMIT_DAILY = 7;
        TIMELINE_LIMIT_WEEKLY = 4;
        TIMELINE_LIMIT_MONTHLY = 2;
        TIMELINE_LIMIT_YEARLY = 0;
      };
    };
  };
}
