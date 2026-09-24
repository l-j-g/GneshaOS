{ config, lib, pkgs, params, ... }:

let
  mediaMountPoint = params.systemSettings.mediaMountPoint;
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
  # Keep Compose project identity, runtime .env, and mutable application data.
  arrDirectory = builtins.dirOf params.systemSettings.arrComposePath;
  proxy = params.systemSettings.dockerProxy or { enable = false; };
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
        ports = [ "8080:8080" "64480:64480" "64480:64480/udp" ]
          ++ lib.optional proxy.enable "127.0.0.1:${toString proxy.port}:8888/tcp";
        networks.default.aliases = [ "qbittorrent" ];
        restart = "unless-stopped";
      };
      prowlarr = app "prowlarr" // { ports = [ "9696:9696" ]; };
      lidarr = app "lidarr" // {
        volumes = [ "./config/lidarr:/config" "${mediaMountPoint}/downloads:/downloads" "${mediaMountPoint}/music:/music" ];
        ports = [ "8686:8686" ];
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
        ports = [ "8081:8080" ];
      };
      audiobookshelf = app "audiobookshelf" // {
        image = "ghcr.io/advplyr/audiobookshelf:latest";
        environment = appEnvironment ++ [ "AUDIOBOOKSHELF_UID=\${PUID}" "AUDIOBOOKSHELF_GID=\${PGID}" ];
        volumes = [
          "./config/audiobookshelf:/config"
          "${mediaMountPoint}/audiobooks:/audiobooks"
          "${mediaMountPoint}/podcasts:/podcasts"
        ];
        ports = [ "13378:80" ];
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
  arrPin = pkgs.writeShellApplication {
    name = "arr-pin";
    runtimeInputs = [ pkgs.docker pkgs.jq pkgs.coreutils pkgs.util-linux ];
    text = ''
      refresh=false
      if [ "''${1:-}" = --refresh ]; then refresh=true
      elif [ "$#" -ne 0 ]; then echo "Usage: arr-pin [--refresh]" >&2; exit 2; fi
      exec 9>${lib.escapeShellArg "${arrDirectory}/.images-lock"}
      flock 9
      # Remove only the former updater belonging to this project, never data.
      if [ "$(docker container inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' watchtower 2>/dev/null || true)" = arr ]; then
        docker stop watchtower
        docker rm watchtower
      fi
      if [ -f ${lib.escapeShellArg imageLock} ] && ! "$refresh"; then exit 0; fi
      temporary=$(mktemp ${lib.escapeShellArg "${arrDirectory}/.images.XXXXXX"})
      trap 'rm -f -- "$temporary" "$temporary.next"' EXIT
      printf '{"services":{}}\n' > "$temporary"
      while IFS=$'\t' read -r service reference; do
        image=$(jq -er --arg service "$service" '.services[$service].image' ${composeFile})
        if "$refresh"; then
          docker pull "$reference"
          image="$reference"
        else
          current=$(docker container inspect --format '{{.Image}}' "$service" 2>/dev/null || true)
          if [ -n "$current" ]; then image="$current"; fi
          if ! docker image inspect "$image" >/dev/null 2>&1; then
            docker pull "$image"
          fi
        fi
        digest=$(docker image inspect --format '{{json .RepoDigests}}' "$image" | jq -er '.[0] | select(test("@sha256:[0-9a-f]{64}$"))')
        jq --arg service "$service" --arg image "$digest" \
          '.services[$service] = {image: $image}' "$temporary" > "$temporary.next"
        mv "$temporary.next" "$temporary"
        printf '%s -> %s\n' "$service" "$digest"
      done < ${imageList}
      # Publish only after every image was resolved successfully.
      chmod 644 "$temporary"
      mv -f "$temporary" ${lib.escapeShellArg imageLock}
    '';
  };
  arrDoctor = pkgs.writeShellApplication {
    name = "arr-doctor";
    runtimeInputs = [ pkgs.docker pkgs.jq pkgs.curl pkgs.util-linux pkgs.coreutils ];
    text = ''
      failures=0
      if mountpoint -q ${lib.escapeShellArg mediaMountPoint}; then
        echo "OK: media drive mounted"
        df -h ${lib.escapeShellArg mediaMountPoint} ${lib.escapeShellArg arrDirectory}
      else
        echo "FAIL: media drive is not mounted"
        failures=$((failures + 1))
      fi
      if ! docker info >/dev/null 2>&1; then
        echo "FAIL: Docker is unavailable or this user lacks permission" >&2
        exit 1
      fi
      while IFS=$'\t' read -r service _reference; do
        state=$(docker inspect --format '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$service" 2>/dev/null || true)
        printf '%s: %s\n' "$service" "''${state:-missing}"
        case "$state" in 'running '|running\ healthy) ;; *) failures=$((failures + 1));; esac
      done < ${imageList}
      vpn=$(docker inspect --format '{{.Id}}' gluetun 2>/dev/null || true)
      torrentNetwork=$(docker inspect --format '{{.HostConfig.NetworkMode}}' qbittorrent 2>/dev/null || true)
      if [ -n "$vpn" ] && [ "$torrentNetwork" = "container:$vpn" ]; then
        echo "OK: qBittorrent shares Gluetun's network namespace"
      else
        echo "FAIL: qBittorrent is not attached to the expected VPN namespace"
        failures=$((failures + 1))
      fi
      for port in 8686 9696 8080 8081 13378 8096; do
        if code=$(curl --noproxy '*' --silent --show-error --max-time 5 --output /dev/null --write-out '%{http_code}' "http://127.0.0.1:$port/"); then
          echo "HTTP $port: $code"
          case "$code" in 2??|3??|401|403) ;; *) failures=$((failures + 1));; esac
        else
          echo "FAIL: HTTP port $port unreachable"
          failures=$((failures + 1))
        fi
      done
      ${lib.optionalString proxy.enable ''
        if curl --noproxy "" --proxy "http://127.0.0.1:${toString proxy.port}" \
          --fail --silent --show-error --max-time 15 --output /dev/null https://cache.nixos.org/nix-cache-info; then
          echo "OK: HTTPS request through Gluetun proxy"
        else
          echo "FAIL: Gluetun proxy connectivity"
          failures=$((failures + 1))
        fi
      ''}
      test "$failures" -eq 0
    '';
  };
  arrUpdate = pkgs.writeShellApplication {
    name = "arr-update";
    runtimeInputs = [ pkgs.util-linux ];
    text = ''
      # Download and resolve every update before asking Compose to recreate.
      ${arrPin}/bin/arr-pin --refresh
      ${arr}/bin/arr up -d
      ${arrDoctor}/bin/arr-doctor
    '';
  };
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
  arr = pkgs.writeShellApplication {
    name = "arr";
    runtimeInputs = [ pkgs.docker ];
    text = ''
      case "''${1:-}" in
        up|create|run|pull)
          if [ ! -r ${lib.escapeShellArg "${arrDirectory}/.env"} ] ||
             [ ! -d ${lib.escapeShellArg "${arrDirectory}/config"} ]; then
            echo "arr: runtime .env or config/ is missing in ${arrDirectory}; restore the existing data or correct systemSettings.arrComposePath before starting." >&2
            exit 1
          fi
          ${arrPin}/bin/arr-pin
          ;;
      esac
      overrides=()
      if [ -f ${lib.escapeShellArg imageLock} ]; then
        overrides=(-f ${lib.escapeShellArg imageLock})
      fi
      exec docker compose --project-name arr \
        --project-directory ${lib.escapeShellArg arrDirectory} \
        --env-file ${lib.escapeShellArg "${arrDirectory}/.env"} \
        -f ${composeFile} "''${overrides[@]}" "$@"
    '';
  };
in

{
  environment.systemPackages = [ arr arrPin arrUpdate arrDoctor ];
  environment.etc."arr/compose.json".source = composeFile;

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
      ExecStart = "${arr}/bin/arr up -d";
      ExecStop = "${arr}/bin/arr down";
      TimeoutStartSec = 300;
      TimeoutStopSec = 60;
    };
  };

  networking.firewall.allowedTCPPorts = [ 8096 8920 ];
  networking.firewall.allowedUDPPorts = [ 7359 ];

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
