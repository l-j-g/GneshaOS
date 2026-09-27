{ config, lib, pkgs, params, ... }:

let
  mediaMountPoint = params.systemSettings.mediaMountPoint;
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
  # before /media unmounts (containers hold volumes).
  systemd.services.docker-compose = {
    description = "Start and stop Docker *arr stack";
    wantedBy = [ "multi-user.target" ];
    # Follow concrete dependencies, not multi-user.target: dependent stacks
    # are ordered before that target and would otherwise create a cycle.
    after = [
      "docker.service"
      "media-directory-setup.service"
      "media.mount"
    ];
    before = [ "shutdown.target" ];
    requires = [
      "docker.service"
      "media-directory-setup.service"
      "media.mount"
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

  # AirVPN forwards 64480 to Gluetun for qBittorrent. Media web interfaces
  # use loopback backends and Tailscale Serve for tailnet-only HTTPS access.
  networking.firewall.allowedTCPPorts = [ 64480 ];
  networking.firewall.allowedUDPPorts = [ 64480 ];

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
    after = [ "media.mount" ];
    requires = [ "media.mount" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/mkdir -p ${lib.concatStringsSep " " mediaDirectories}";
      RemainAfterExit = true;
    };
  };
}
