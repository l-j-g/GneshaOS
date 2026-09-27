{ config, lib, pkgs, ... }:

# Load the private host profile into NetworkManager without placing it in the
# Nix store. The resulting root-only keyfile makes the tunnel selectable in
# nmtui; NetworkManager autoconnect defaults to disabled.
let
  avpn = config.services.gnesha.airvpn;
  profilePath = avpn.profilePath;
  profileArg = lib.escapeShellArg profilePath;
  homeArg = lib.escapeShellArg avpn.homeDirectory;
  userArg = lib.escapeShellArg avpn.userName;
  connectionPath = "/etc/NetworkManager/system-connections/airvpn.nmconnection";
  connectionUuid = "60d25a7b-a0a9-56c7-8a6d-ea7ea3061f65";

  validateProfile = pkgs.writeShellScript "airvpn-nm-validate-profile" ''
    set -euo pipefail

    profile=${profileArg}
    [[ "$profile" == /* ]] || { echo "AirVPN profile path must be absolute" >&2; exit 1; }
    [[ -f "$profile" && ! -L "$profile" && -s "$profile" ]] \
      || { echo "AirVPN profile is missing, empty, or not regular" >&2; exit 1; }

    resolved=$(${pkgs.coreutils}/bin/realpath -e -- "$profile")
    [[ "$resolved" == "$profile" ]] \
      || { echo "AirVPN profile path contains a symlink" >&2; exit 1; }

    expectedUid=$(${pkgs.coreutils}/bin/id -u ${userArg})
    home=$(${pkgs.coreutils}/bin/realpath -e -- ${homeArg})
    case "$profile" in
      "$home"/*) profileInHome=true ;;
      *) profileInHome=false ;;
    esac

    fileMetadata=$(${pkgs.coreutils}/bin/stat -c '%u %a %F' -- "$profile")
    read -r fileOwner fileMode fileType <<< "$fileMetadata"
    [[ "$fileMode" == 600 && "$fileType" == "regular file" ]] \
      || { echo "AirVPN profile must be mode 600" >&2; exit 1; }
    if [[ "$fileOwner" != 0 ]]; then
      [[ "$profileInHome" == true && "$fileOwner" == "$expectedUid" ]] \
        || { echo "AirVPN profile must be root-owned or owned by the configured user inside their home" >&2; exit 1; }
    fi

    directory=$(${pkgs.coreutils}/bin/dirname -- "$profile")
    while :; do
      [[ -d "$directory" && ! -L "$directory" ]] \
        || { echo "AirVPN profile parent is missing or a symlink" >&2; exit 1; }
      resolved=$(${pkgs.coreutils}/bin/realpath -e -- "$directory")
      [[ "$resolved" == "$directory" ]] \
        || { echo "AirVPN profile parent contains a symlink" >&2; exit 1; }
      directoryMetadata=$(${pkgs.coreutils}/bin/stat -c '%u %a %F' -- "$directory")
      read -r directoryOwner directoryMode directoryType <<< "$directoryMetadata"
      [[ "$directoryType" == "directory" ]] \
        || { echo "AirVPN profile parents must be directories" >&2; exit 1; }
      if [[ "$directoryOwner" != 0 ]]; then
        [[ "$profileInHome" == true && "$directoryOwner" == "$expectedUid" ]] \
          || { echo "AirVPN profile parents must be root-owned or owned by the configured user inside their home" >&2; exit 1; }
      fi
      directoryModeValue=$((8#$directoryMode))
      (( (directoryModeValue & 0022) == 0 )) \
        || { echo "AirVPN profile parents must not be group/world writable" >&2; exit 1; }
      [[ "$directory" == "/" ]] && break
      directory=$(${pkgs.coreutils}/bin/dirname -- "$directory")
    done
  '';

  loadConnection = pkgs.writeShellScript "airvpn-nm-load-profile" ''
    set -euo pipefail
    ${validateProfile}
    ${pkgs.python3}/bin/python3 ${./airvpn-nm-profile.py} \
      ${profileArg} ${lib.escapeShellArg connectionPath} ${if avpn.autostart then "true" else "false"}
    ${pkgs.networkmanager}/bin/nmcli connection load ${lib.escapeShellArg connectionPath}
  '';

  removeConnection = pkgs.writeShellScript "airvpn-nm-remove-profile" ''
    set -euo pipefail
    ${pkgs.networkmanager}/bin/nmcli connection delete uuid ${connectionUuid} || true
    ${pkgs.coreutils}/bin/rm -f -- ${lib.escapeShellArg connectionPath}
  '';
in
{
  options.services.gnesha.airvpn = {
    enable = lib.mkEnableOption "the host AirVPN NetworkManager profile";
    profilePath = lib.mkOption {
      type = lib.types.str;
      default = "/etc/airvpn/host.conf";
      description = "Absolute path to the private wg-quick profile outside the Nix store.";
    };
    autostart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow NetworkManager to connect the AirVPN profile automatically.";
    };
    userName = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    homeDirectory = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
  };

  config = lib.mkMerge [
    {
      # Keep stale private key material out of the connection directory on boot,
      # even when this feature has since been disabled.
      systemd.tmpfiles.rules = [ "r! ${connectionPath}" ];
    }
    (lib.mkIf avpn.enable {
      assertions = [
        {
          assertion = lib.hasPrefix "/" avpn.profilePath;
          message = "services.gnesha.airvpn.profilePath must be absolute";
        }
        {
          assertion = avpn.userName != "" && lib.hasPrefix "/" avpn.homeDirectory;
          message = "services.gnesha.airvpn requires userName and an absolute homeDirectory";
        }
      ];
      boot.kernelModules = [ "wireguard" ];
      networking.resolvconf.enable = true;
      environment.systemPackages = [ pkgs.wireguard-tools ];

      # Waybar may read only the handshake timestamp for this interface. Keep
      # the privileged query fixed; do not grant arbitrary wg or shell access.
      security.sudo.extraRules = [
        {
          users = [ avpn.userName ];
          commands = [
            {
              command = "${pkgs.wireguard-tools}/bin/wg show airvpn-wg latest-handshakes";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];

      systemd.services.airvpn-networkmanager-profile = {
        description = "Load the protected AirVPN profile into NetworkManager";
        wantedBy = [ "multi-user.target" ];
        requires = [ "NetworkManager.service" ];
        after = [ "NetworkManager.service" ];
        unitConfig = {
          ConditionPathExists = profilePath;
          RequiresMountsFor = profilePath;
        };
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = "30s";
          ExecStartPre = validateProfile;
          ExecStart = loadConnection;
          ExecStopPost = removeConnection;
        };
      };
    })
  ];
}
