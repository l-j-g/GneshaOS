{ config, lib, pkgs, params, utils, ... }:

let
  mediaMountPoint = params.systemSettings.mediaMountPoint;
  mediaMountUnit = "${utils.escapeSystemdPath mediaMountPoint}.mount";
  media = import ./media/compose.nix { inherit config lib pkgs params; };
  commands = import ./media/commands.nix {
    inherit lib pkgs;
    inherit (media) arrDirectory mediaMountPoint proxy imageList imageLock composeFile;
  };
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
  environment.systemPackages = with commands; [ arr arrPin arrUpdate arrDoctor ];
  environment.etc."arr/compose.json".source = media.composeFile;

  # Docker engine + compose for the self-hosted media stack (Lidarr/Prowlarr/etc.)
  virtualisation.docker.enable = true;
  virtualisation.docker.autoPrune = {
    enable = true;
    dates = "weekly";
  };
  # Docker must be able to pull the containers that provide the local proxy
  # even when that proxy is stopped. This only bypasses the proxy for daemon
  # registry traffic; qBittorrent still shares Gluetun's VPN namespace.
  systemd.services.docker.serviceConfig.UnsetEnvironment = [
    "http_proxy" "https_proxy" "all_proxy"
    "HTTP_PROXY" "HTTPS_PROXY" "ALL_PROXY"
  ];
  # Let the user run docker without sudo and manage the stack
  users.users.${params.userSettings.userName}.extraGroups = [
    "docker"
    "input"
  ];

  # Start the Docker *arr stack after its dependencies are ready, and stop it
  # before the configured media filesystem unmounts (containers hold volumes).
  systemd.services.docker-compose = {
    description = "Start and stop Docker *arr stack";
    wantedBy = [ "multi-user.target" ];
    # Follow concrete dependencies, not multi-user.target: dependent stacks
    # are ordered before that target and would otherwise create a cycle.
    after = [
      "docker.service"
      "media-directory-setup.service"
      mediaMountUnit
    ];
    before = [ "shutdown.target" ];
    requires = [
      "docker.service"
      "media-directory-setup.service"
      mediaMountUnit
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${commands.arr}/bin/arr up -d";
      ExecStop = "${commands.arr}/bin/arr down";
      TimeoutStartSec = 300;
      TimeoutStopSec = 60;
    };
  };

  # Emby uses host networking. Permit its HTTP UI from the home Wi-Fi subnet
  # without exposing it on VPN interfaces or to other source networks.
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -i wlp0s20f3 -s 192.168.1.0/24 -p tcp --dport 8096 -j nixos-fw-accept
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D nixos-fw -i wlp0s20f3 -s 192.168.1.0/24 -p tcp --dport 8096 -j nixos-fw-accept 2>/dev/null || true
  '';

  # Other media web interfaces use loopback backends and Tailscale Serve for
  # tailnet-only HTTPS access. Provider-forwarded torrent traffic stays inside
  # Gluetun's VPN namespace and is not opened on host interfaces.
  networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [
    8443 # Emby -> 127.0.0.1:8096
    8444 # qBittorrent -> 127.0.0.1:8080
    8445 # Prowlarr -> 127.0.0.1:9696
    8446 # Lidarr -> 127.0.0.1:8686
    8447 # SABnzbd -> 127.0.0.1:8081
    8448 # Audiobookshelf -> 127.0.0.1:13378
  ];

  systemd.services.tailscale-media-serve = {
    description = "Expose local media web interfaces over Tailscale Serve";
    after = [ "tailscaled.service" "docker-compose.service" ];
    wants = [ "tailscaled.service" "docker-compose.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ config.services.tailscale.package ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      tailscale serve --yes --bg --https=8443 http://127.0.0.1:8096
      tailscale serve --yes --bg --https=8444 http://127.0.0.1:8080
      tailscale serve --yes --bg --https=8445 http://127.0.0.1:9696
      tailscale serve --yes --bg --https=8446 http://127.0.0.1:8686
      tailscale serve --yes --bg --https=8447 http://127.0.0.1:8081
      tailscale serve --yes --bg --https=8448 http://127.0.0.1:13378
    '';
    preStop = ''
      tailscale serve --yes --https=8443 off || true
      tailscale serve --yes --https=8444 off || true
      tailscale serve --yes --https=8445 off || true
      tailscale serve --yes --https=8446 off || true
      tailscale serve --yes --https=8447 off || true
      tailscale serve --yes --https=8448 off || true
    '';
  };

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
