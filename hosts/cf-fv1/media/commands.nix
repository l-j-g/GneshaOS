{ lib, pkgs, arrDirectory, mediaMountPoint, proxy, imageList, imageLock, composeFile }:

let
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
  inherit arr arrPin arrUpdate arrDoctor;
}
