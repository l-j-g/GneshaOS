{ config, lib, pkgs, params, ... }:

let
  mediaMountPoint = params.systemSettings.mediaMountPoint;
  mediaUiBindAddress = params.systemSettings.mediaUiBindAddress or "127.0.0.1";
  # Keep Compose project identity, runtime .env, and mutable application data.
  arrDirectory = builtins.dirOf params.systemSettings.arrComposePath;
  proxy = params.systemSettings.dockerProxy or { enable = false; };
  uiPort = hostPort: containerPort:
    "${mediaUiBindAddress}:${toString hostPort}:${toString containerPort}";
  appEnvironment = [ "PUID=\${PUID}" "PGID=\${PGID}" "TZ=\${TZ}" ];
  app = name: {
    image = "lscr.io/linuxserver/${name}:latest";
    container_name = name;
    environment = appEnvironment;
    volumes = [ "./config/${name}:/config" ];
    restart = "unless-stopped";
  };
  composeDefinition = {
    name = "arr";
    services = {
      gluetun = {
        image = "qmcgaw/gluetun:latest";
        container_name = "gluetun";
        cap_add = [ "NET_ADMIN" ];
        devices = [ "/dev/net/tun:/dev/net/tun" ];
        environment = [
          "VPN_SERVICE_PROVIDER=custom"
          "VPN_TYPE=wireguard"
          "WIREGUARD_ADDRESSES=10.164.61.233/32"
          "FIREWALL_INPUT_PORTS=8080"
          "FIREWALL_VPN_INPUT_PORTS=64480"
          "TZ=\${TZ}"
        ] ++ lib.optional proxy.enable "HTTPPROXY=on";
        volumes = [ "./config/gluetun:/gluetun/wireguard" ];
        ports = [ (uiPort 8080 8080) "64480:64480" "64480:64480/udp" ]
          ++ lib.optional proxy.enable "127.0.0.1:${toString proxy.port}:8888/tcp";
        networks.default.aliases = [ "qbittorrent" ];
        restart = "unless-stopped";
      };
      prowlarr = app "prowlarr" // { ports = [ (uiPort 9696 9696) ]; };
      lidarr = app "lidarr" // {
        volumes = [ "./config/lidarr:/config" "${mediaMountPoint}/downloads:/downloads" "${mediaMountPoint}/music:/music" ];
        ports = [ (uiPort 8686 8686) ];
        depends_on = [ "prowlarr" ];
      };
      qbittorrent = app "qbittorrent" // {
        environment = appEnvironment ++ [ "WEBUI_PORT=8080" ];
        volumes = [
          "./config/qbittorrent:/config"
          "${mediaMountPoint}/downloads:/downloads"
          "${mediaMountPoint}/torrents:/torrents"
          "${mediaMountPoint}/torrents/watch:/watch"
        ];
        network_mode = "service:gluetun";
        depends_on.gluetun.condition = "service_healthy";
      };
      sabnzbd = app "sabnzbd" // {
        volumes = [ "./config/sabnzbd:/config" "${mediaMountPoint}/downloads:/downloads" ];
        ports = [ (uiPort 8081 8080) ];
      };
      audiobookshelf = app "audiobookshelf" // {
        image = "ghcr.io/advplyr/audiobookshelf:latest";
        environment = appEnvironment ++ [ "AUDIOBOOKSHELF_UID=\${PUID}" "AUDIOBOOKSHELF_GID=\${PGID}" ];
        volumes = [
          "./config/audiobookshelf:/config"
          "${mediaMountPoint}/audiobooks:/audiobooks"
          "${mediaMountPoint}/podcasts:/podcasts"
        ];
        ports = [ (uiPort 13378 80) ];
      };
      emby = {
        image = "emby/embyserver:4.10.0.40";
        container_name = "emby";
        # Change this release explicitly; arr-pin records the resolved digest.
        environment = {
          UID = "\${PUID}";
          GID = "\${PGID}";
          TZ = "\${TZ}";
          GIDLIST = lib.concatStringsSep "," (map toString [
            config.users.groups.render.gid
            config.users.groups.video.gid
          ]);
        };
        volumes = [ "./config/emby:/config" "${mediaMountPoint}:${mediaMountPoint}:ro" ];
        devices = [ "/dev/dri:/dev/dri" ];
        network_mode = "host";
        restart = "unless-stopped";
      };
    };
  };
  imageReferences = lib.mapAttrs (_: service: service.image) composeDefinition.services;
  imageList = pkgs.writeText "arr-images.tsv" (lib.concatStringsSep "\n"
    (lib.mapAttrsToList (name: image: "${name}\t${image}") imageReferences) + "\n");
  imageLock = "${arrDirectory}/images.lock.json";
  # Baseline matches the installed images. Explicit arr-update writes a runtime
  # override; ordinary rebuilds never follow moving tags.
  pinnedImages = {
    gluetun = "qmcgaw/gluetun@sha256:12df8b20528d4cd5e9b6e827d40f2886cf78e53e7e9afc750050648c31183793";
    prowlarr = "lscr.io/linuxserver/prowlarr@sha256:1295cff29d10b486c0d8324d1559a552140a5932bf8b3d87e398654414f63f92";
    lidarr = "lscr.io/linuxserver/lidarr@sha256:bfec0ec2dc351fa5928379d785b08be395886f109393b9040ed7973bd1008060";
    qbittorrent = "lscr.io/linuxserver/qbittorrent@sha256:b6ab43fe86039e5bdd3cc0b59b946414fcff0c8183e93636e6cb438fdac45028";
    sabnzbd = "lscr.io/linuxserver/sabnzbd@sha256:b0f9755d795913bd26ae3f3a12805668ab0681ab847a7624568559c573fc7cae";
    audiobookshelf = "ghcr.io/advplyr/audiobookshelf@sha256:180acad33d69c99ed208676465d8edcb268fa46967735579a7810859885b1a8e";
    emby = "emby/embyserver@sha256:3aafff933d3f28d23ed0bc201022abe71c0aa80deb17177566c726b9bbc686c6";
  };
  pinnedCompose = composeDefinition // {
    services = lib.mapAttrs (name: service: service // { image = pinnedImages.${name}; }) composeDefinition.services;
  };
  composeFile = pkgs.writeText "arr-compose.json" (builtins.toJSON pinnedCompose);
in
{
  inherit arrDirectory mediaMountPoint proxy imageList imageLock composeFile;
}
