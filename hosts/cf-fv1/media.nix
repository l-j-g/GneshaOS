# Shared media directories and desktop access, independent of the ARR stack.
{
  lib,
  pkgs,
  params,
  utils,
  ...
}:
let
  mediaMountPoint = params.systemSettings.mediaMountPoint;
  mediaMountUnit = "${utils.escapeSystemdPath mediaMountPoint}.mount";
  mediaDirectories = [
    "${mediaMountPoint}/downloads"
    "${mediaMountPoint}/torrents"
    "${mediaMountPoint}/music"
    "${mediaMountPoint}/audiobooks"
    "${mediaMountPoint}/podcasts"
    "${mediaMountPoint}/Pictures"
    "${mediaMountPoint}/Pictures/Screenshots"
    "${mediaMountPoint}/Videos"
  ];
  mediaDirectorySetup = pkgs.writeShellScript "media-directory-setup" ''
    set -eu
    if ! ${pkgs.util-linux}/bin/mountpoint -q ${lib.escapeShellArg mediaMountPoint}; then
      echo "media-directory-setup: ${mediaMountPoint} is not a mounted filesystem; refusing to create directories on the root filesystem." >&2
      exit 1
    fi
    for directory in ${lib.concatMapStringsSep " " lib.escapeShellArg mediaDirectories}; do
      if [ -L "$directory" ] || { [ -e "$directory" ] && [ ! -d "$directory" ]; }; then
        echo "media-directory-setup: refusing non-directory or symlink $directory" >&2
        exit 1
      fi
      ${pkgs.coreutils}/bin/mkdir -p -- "$directory"
      if [ ! -w "$directory" ] || [ ! -x "$directory" ]; then
        echo "media-directory-setup: $directory is not writable/searchable by $(id -un)" >&2
        exit 1
      fi
    done
  '';
in
{
  # Private mesh VPN for reaching self-hosted services from any device anywhere
  services.tailscale.enable = true;
  services.gvfs.enable = true;

  # Create the required media directories only after MooGoo is mounted.
  # This also keeps a missing nofail mount from causing directories to be
  # created on the root filesystem at /media.
  systemd.services.media-directory-setup = {
    description = "Create user media directories on the MooGoo drive";
    wantedBy = [ "multi-user.target" ];
    after = [ mediaMountUnit ];
    requires = [ mediaMountUnit ];
    serviceConfig = {
      Type = "oneshot";
      User = params.userSettings.userName;
      ExecStart = mediaDirectorySetup;
      RemainAfterExit = true;
    };
  };
}
