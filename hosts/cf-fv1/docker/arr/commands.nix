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
      expected_services=$(jq -cn --rawfile services ${imageList} '$services | split("\n") | map(select(length > 0) | split("\t")[0]) | sort')
      validate_lock() {
        jq -e --argjson expected "$expected_services" '
          type == "object" and keys == ["services"] and
          (.services | type == "object") and
          ((.services | keys | sort) == $expected) and
          all(.services[]; type == "object" and keys == ["image"] and
            (.image | type == "string" and test("^.+@sha256:[0-9a-f]{64}$")))
        ' "$1" >/dev/null
      }
      if [ -f ${lib.escapeShellArg imageLock} ]; then
        if ! validate_lock ${lib.escapeShellArg imageLock}; then
          echo "arr-pin: invalid image lock ${imageLock}; preserve it for review, then move or repair it before retrying." >&2
          exit 1
        fi
      fi
      # Remove only the former updater belonging to this project, never data.
      if [ "$(docker container inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' watchtower 2>/dev/null || true)" = arr ]; then
        docker stop watchtower
        docker rm watchtower
      fi
      if [ -f ${lib.escapeShellArg imageLock} ] && ! "$refresh"; then exit 0; fi
      temporary=$(mktemp ${lib.escapeShellArg "${arrDirectory}/.images.XXXXXX"})
      previous_temporary=""
      trap 'rm -f -- "$temporary" "$temporary.next" "$previous_temporary"' EXIT
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
      if [ -f ${lib.escapeShellArg imageLock} ]; then
        while IFS=$'\t' read -r service image; do
          rollback_image="''${image%@*}:gnesha-rollback"
          if ! docker image tag "$image" "$rollback_image"; then
            echo "arr-pin: could not retain the previous $service image as $rollback_image; current image lock was not changed." >&2
            exit 1
          fi
        done < <(jq -r '.services | to_entries[] | [.key, .value.image] | @tsv' ${lib.escapeShellArg imageLock})
        previous_temporary=$(mktemp ${lib.escapeShellArg "${arrDirectory}/.images-previous.XXXXXX"})
        cp -- ${lib.escapeShellArg imageLock} "$previous_temporary"
        chmod 644 "$previous_temporary"
        mv -f -- "$previous_temporary" ${lib.escapeShellArg "${imageLock}.previous.json"}
        previous_temporary=""
      fi
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
      ${arrWaitReady}/bin/arr-wait-ready
      ${arrDoctor}/bin/arr-doctor
    '';
  };
  arrWaitReady = pkgs.writeShellApplication {
    name = "arr-wait-ready";
    runtimeInputs = [ pkgs.docker pkgs.coreutils ];
    text = ''
      timeout_seconds=''${ARR_READY_TIMEOUT:-300}
      interval_seconds=''${ARR_READY_INTERVAL:-5}
      case "$timeout_seconds:$interval_seconds" in *[!0-9:]*|:*)
        echo "arr-wait-ready: timeout and interval must be positive integers" >&2
        exit 2
        ;;
      esac
      if [ "$timeout_seconds" -lt 1 ] || [ "$interval_seconds" -lt 1 ]; then
        echo "arr-wait-ready: timeout and interval must be positive integers" >&2
        exit 2
      fi
      mapfile -t services < <(cut -f1 ${imageList})
      started=$SECONDS
      ready=false
      while [ "$((SECONDS - started))" -lt "$timeout_seconds" ]; do
        ready=true
        for service in "''${services[@]}"; do
          remaining=$((timeout_seconds - (SECONDS - started)))
          if [ "$remaining" -lt 1 ]; then ready=false; break; fi
          state=$(timeout "$remaining" docker container inspect --format '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$service" 2>/dev/null || true)
          case "$state" in 'running '|running\ healthy) ;; *) ready=false ;; esac
        done
        if [ "$ready" = true ]; then break; fi
        remaining=$((timeout_seconds - (SECONDS - started)))
        if [ "$remaining" -gt 0 ]; then
          sleep "$(( interval_seconds < remaining ? interval_seconds : remaining ))"
        fi
      done
      echo "arr-update readiness results:"
      for service in "''${services[@]}"; do
        state=$(timeout 1s docker container inspect --format '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$service" 2>/dev/null || true)
        printf '%s: %s\n' "$service" "''${state:-missing}"
      done
      if [ "$ready" != true ]; then
        echo "arr-wait-ready: services did not become ready within ''${timeout_seconds}s" >&2
        exit 1
      fi
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
  inherit arr arrPin arrUpdate arrDoctor arrWaitReady;
}
