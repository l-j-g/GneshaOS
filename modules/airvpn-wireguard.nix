{ config, lib, pkgs, params, ... }:

# System-wide AirVPN WireGuard tunnel, toggled from
# params.systemSettings.airVpn. The *.conf profile contains private keys and
# must stay root-owned outside the repository and Nix store.
let
  avpn = params.systemSettings.airVpn or { };
  profilePath = avpn.configPath or "/etc/airvpn/host.conf";
  profileArg = lib.escapeShellArg profilePath;
  runtimeConfig = "/run/airvpn-wg/airvpn-wg.conf";

  validateProfile = pkgs.writeShellScript "airvpn-wg-validate-profile" ''
    set -euo pipefail

    profile=${profileArg}
    if (( $# > 0 )); then
      profile="$1"
    fi

    fail() {
      printf 'AirVPN profile rejected: %s\n' "$1" >&2
      exit 1
    }

    [[ "$profile" == /* ]] || fail "path must be absolute"
    [[ -f "$profile" && ! -L "$profile" && -s "$profile" ]] || fail "file is missing, empty, or not regular"

    resolved=$(${pkgs.coreutils}/bin/realpath -e -- "$profile") || fail "cannot resolve file"
    [[ "$resolved" == "$profile" ]] || fail "symlink path is not trusted"

    fileMetadata=$(${pkgs.coreutils}/bin/stat -c '%u %a %F' -- "$profile") || fail "cannot inspect file"
    read -r fileOwner fileMode fileType <<< "$fileMetadata"
    [[ "$fileOwner" == 0 && "$fileMode" == 600 && "$fileType" == "regular file" ]] \
      || fail "file must be a root-owned regular file with mode 600"

    directory=$(${pkgs.coreutils}/bin/dirname -- "$profile")
    while :; do
      [[ -d "$directory" && ! -L "$directory" ]] || fail "parent directory is missing or a symlink"
      resolved=$(${pkgs.coreutils}/bin/realpath -e -- "$directory") || fail "cannot resolve parent directory"
      [[ "$resolved" == "$directory" ]] || fail "parent path contains a symlink"

      directoryMetadata=$(${pkgs.coreutils}/bin/stat -c '%u %a %F' -- "$directory") \
        || fail "cannot inspect parent directory"
      read -r directoryOwner directoryMode directoryType <<< "$directoryMetadata"
      [[ "$directoryOwner" == 0 && "$directoryType" == "directory" ]] \
        || fail "parent directories must be root-owned"

      directoryModeValue=$((8#$directoryMode))
      (( (directoryModeValue & 0022) == 0 )) \
        || fail "parent directories must not be group- or world-writable"

      [[ "$directory" == "/" ]] && break
      directory=$(${pkgs.coreutils}/bin/dirname -- "$directory")
    done
  '';

  startTunnel = pkgs.writeShellScript "airvpn-wg-start" ''
    set -euo pipefail

    profile=${profileArg}
    if (( $# > 0 )); then
      profile="$1"
    fi
    wgQuick=${lib.escapeShellArg "${pkgs.wireguard-tools}/bin/wg-quick"}
    if (( $# > 1 )); then
      wgQuick="$2"
    fi

    ${validateProfile} "$profile"

    ${pkgs.coreutils}/bin/install --owner=0 --group=0 --mode=600 -- \
      "$profile" ${lib.escapeShellArg runtimeConfig}
    exec "$wgQuick" up ${lib.escapeShellArg runtimeConfig}
  '';
in
{
  config = lib.mkIf (avpn.enable or false) {
    # wg-quick configures the interface, routes, DNS, and MTU from the profile.
    boot.kernelModules = [ "wireguard" ];
    environment.systemPackages = [ pkgs.wireguard-tools ];
    networking.resolvconf.enable = true;
    networking.networkmanager.unmanaged = [ "interface-name:airvpn-wg" ];

    systemd.services.airvpn-wg = {
      description = "AirVPN WireGuard tunnel";
      # Keep the host tunnel available on demand without connecting at boot.
      wantedBy = [ ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPre = validateProfile;
        ExecStart = startTunnel;
        # Runs on normal stop and failed startup, so a partially-created
        # tunnel is torn down before systemd removes the private runtime dir.
        ExecStopPost = [
          "-${pkgs.wireguard-tools}/bin/wg-quick down ${runtimeConfig}"
          "${pkgs.coreutils}/bin/rm -f ${runtimeConfig}"
        ];
        RuntimeDirectory = "airvpn-wg";
        RuntimeDirectoryMode = "0700";
        RuntimeDirectoryPreserve = "no";
      };
    };

    # The toggle is safe only because the service validates a root-owned
    # profile before passing it to wg-quick, which executes profile hooks.
    security.sudo.extraRules = [
      {
        groups = [ "wheel" ];
        commands = map
          (action: {
            command = "${pkgs.systemd}/bin/systemctl ${action} airvpn-wg";
            options = [ "NOPASSWD" ];
          })
          [ "start" "stop" "restart" ];
      }
    ];
  };
}
