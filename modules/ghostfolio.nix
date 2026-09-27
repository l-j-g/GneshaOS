# Run Ghostfolio and its persistent PostgreSQL and Redis services with Docker
# Compose. Keep migration preflight available while the feature is disabled.
{ config, lib, pkgs, ... }:

let
  ghost = config.services.gnesha.ghostfolio;
  ghostfolioDirectory = ghost.runtimeDirectory;
  secretsFile = ghost.secretsFile;
  proxy = ghost.proxy;
  imageReferences = {
    postgres = "docker.io/library/postgres:${ghost.postgresMajor}-alpine";
    redis = "docker.io/library/redis:7-alpine";
    ghostfolio = "docker.io/ghostfolio/ghostfolio:latest";
  };
  imageServices = builtins.attrNames imageReferences;
  imageList = pkgs.writeText "ghostfolio-images.tsv" (lib.concatStringsSep "\n"
    (lib.mapAttrsToList (name: image: "${name}\t${image}") imageReferences) + "\n");
  imageLock = "${ghostfolioDirectory}/images.lock.json";
  imageLockPrevious = "${imageLock}.previous.json";
  preflight = pkgs.writeShellApplication {
    name = "ghostfolio-preflight";
    runtimeInputs = [ pkgs.docker pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnused pkgs.jq ];
    text = ''
      fail() { echo "ghostfolio-preflight: $*" >&2; exit 1; }
      allow_unpinned=false
      if [ "''${1:-}" = --allow-unpinned ] && [ "$#" -eq 1 ]; then
        allow_unpinned=true
      elif [ "$#" -ne 0 ]; then
        echo "Usage: ghostfolio-preflight [--allow-unpinned]" >&2
        exit 2
      fi

      if [ ! -f ${lib.escapeShellArg secretsFile} ] || [ -L ${lib.escapeShellArg secretsFile} ]; then
        fail "runtime secrets file is missing or not a regular file: ${secretsFile}"
      fi
      mode=$(stat -c '%a' -- ${lib.escapeShellArg secretsFile})
      [ "$mode" = 600 ] || fail "secrets file must have mode 600: ${secretsFile}"
      grep -qE '^DATABASE_PASSWORD=[0-9A-Fa-f]{64}$' ${lib.escapeShellArg secretsFile} \
        || fail "secrets file must define DATABASE_PASSWORD as 64 hexadecimal characters"
      grep -qE '^REDIS_PASSWORD=[0-9A-Fa-f]{64}$' ${lib.escapeShellArg secretsFile} \
        || fail "secrets file must define REDIS_PASSWORD as 64 hexadecimal characters"

      marker=${lib.escapeShellArg "${ghostfolioDirectory}/.database-imported"}
      database=${lib.escapeShellArg "${ghostfolioDirectory}/postgres"}
      import=${lib.escapeShellArg "${ghostfolioDirectory}/initial-database.sql"}
      import_state=${lib.escapeShellArg "${ghostfolioDirectory}/.database-import-state"}
      if [ "$allow_unpinned" != true ] && [ -e "$marker" ]; then
        [ -s "$database/PG_VERSION" ] || fail "import marker exists but PostgreSQL data is missing; inspect the data before retrying"
        actual_major=$(cat "$database/PG_VERSION")
        [ "$actual_major" = ${lib.escapeShellArg ghost.postgresMajor} ] \
          || fail "PostgreSQL data is major $actual_major but the configured image is major ${ghost.postgresMajor}"
      elif [ "$allow_unpinned" != true ]; then
        state=""
        [ ! -f "$import_state" ] || state=$(cat "$import_state")
        case "$state" in
          importing|failed)
            fail "database import state is '$state'; automatic retry is blocked. Review the partial target and restore a fresh target before retrying"
            ;;
          ready|imported|"") ;;
          *) fail "unknown database import state '$state'; inspect the target before retrying" ;;
        esac
        if [ "$state" = imported ]; then
          [ -s "$database/PG_VERSION" ] || fail "import state is imported but PostgreSQL data is missing"
          actual_major=$(cat "$database/PG_VERSION")
          [ "$actual_major" = ${lib.escapeShellArg ghost.postgresMajor} ] \
            || fail "PostgreSQL data is major $actual_major but the configured image is major ${ghost.postgresMajor}"
        elif [ "$state" != ready ] && [ -d "$database" ] && [ -n "$(find "$database" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
          fail "PostgreSQL data already exists without a completion marker; inspect or restore a fresh target before importing"
        fi
        if [ "$state" != imported ]; then
          [ -s "$import" ] || fail "SQL dump is missing or empty: ${ghostfolioDirectory}/initial-database.sql"
          dump_major=$(sed -nE 's/^-- Dumped from database version ([0-9]+)\..*/\1/p' "$import" | head -n 1)
          [ -n "$dump_major" ] || fail "SQL dump has no pg_dump source-version header; verify its source and export method"
          [ "$dump_major" = ${lib.escapeShellArg ghost.postgresMajor} ] \
            || fail "SQL dump source major is $dump_major but the configured PostgreSQL image is major ${ghost.postgresMajor}"
        fi
      fi

      expected_services=${lib.escapeShellArg (builtins.toJSON imageServices)}
      validate_lock() {
        jq -e --argjson expected "$expected_services" --arg major ${lib.escapeShellArg ghost.postgresMajor} '
          type == "object" and (keys | sort) == ["postgresMajor", "services"] and
          .postgresMajor == $major and (.services | type == "object") and
          ((.services | keys | sort) == $expected) and
          all(.services[]; type == "object" and keys == ["image"] and
            (.image | type == "string" and test("^.+@sha256:[0-9a-f]{64}$")))
        ' "$1" >/dev/null
      }
      if [ -f ${lib.escapeShellArg imageLock} ]; then
        [ ! -L ${lib.escapeShellArg imageLock} ] || fail "image lock must not be a symlink"
        validate_lock ${lib.escapeShellArg imageLock} \
          || fail "image lock is corrupt, stale, or uses a different PostgreSQL major; inspect it and follow the explicit migration procedure"
      elif [ "$allow_unpinned" != true ]; then
        fail "pinned image lock is missing; run ghostfolio-pin --refresh before starting the stack"
      fi

      timeout 10s docker info >/dev/null 2>&1 || fail "Docker daemon is unavailable or permission was denied"
      ${lib.optionalString proxy.enable ''
        timeout 10s docker network inspect arr_default >/dev/null 2>&1 \
          || fail "Docker network arr_default is missing; start the media stack before Ghostfolio"
      ''}
      compose_args=(docker compose --project-name ghostfolio \
        --project-directory ${lib.escapeShellArg ghostfolioDirectory} \
        --env-file ${lib.escapeShellArg secretsFile} \
        -f ${composeFile})
      if [ -f ${lib.escapeShellArg imageLock} ]; then compose_args+=(-f ${lib.escapeShellArg imageLock}); fi
      timeout 20s "''${compose_args[@]}" config --quiet \
        || fail "Compose configuration or runtime prerequisites are invalid"
      echo "ghostfolio-preflight: prerequisites pass for PostgreSQL major ${ghost.postgresMajor}; no data was changed"
    '';
  };
  composeFile = pkgs.writeText "ghostfolio-compose.json" (builtins.toJSON {
    name = "ghostfolio";
    services = {
      postgres = {
        image = imageReferences.postgres;
        pull_policy = "never";
        restart = "unless-stopped";
        environment = {
          POSTGRES_DB = "ghostfolio";
          POSTGRES_USER = "ghostfolio";
          POSTGRES_PASSWORD = "\${DATABASE_PASSWORD:?DATABASE_PASSWORD is required}";
        };
        volumes = [ "${ghostfolioDirectory}/postgres:/var/lib/postgresql/data" ];
        healthcheck = {
          test = [ "CMD-SHELL" "pg_isready -U ghostfolio -d ghostfolio" ];
          interval = "10s";
          timeout = "5s";
          retries = 12;
        };
        networks = [ "default" ];
      };
      redis = {
        image = imageReferences.redis;
        pull_policy = "never";
        restart = "unless-stopped";
        environment.REDIS_PASSWORD = "\${REDIS_PASSWORD:?REDIS_PASSWORD is required}";
        command = [ "sh" "-c" "redis-server --requirepass \"$$REDIS_PASSWORD\"" ];
        healthcheck = {
          test = [ "CMD-SHELL" "redis-cli --pass \"$$REDIS_PASSWORD\" ping | grep PONG" ];
          interval = "10s";
          timeout = "5s";
          retries = 12;
        };
        networks = [ "default" ];
      };
      ghostfolio = {
        image = imageReferences.ghostfolio;
        pull_policy = "never";
        restart = "unless-stopped";
        init = true;
        cap_drop = [ "ALL" ];
        security_opt = [ "no-new-privileges:true" ];
        env_file = [ secretsFile ];
        environment = {
          NODE_ENV = "production";
          HOST = "0.0.0.0";
          PORT = "3333";
          ROOT_URL = "http://localhost:3333";
          DATABASE_URL = "postgresql://ghostfolio:\${DATABASE_PASSWORD:?DATABASE_PASSWORD is required}@postgres:5432/ghostfolio?sslmode=disable";
          REDIS_HOST = "redis";
          REDIS_PORT = "6379";
          REDIS_PASSWORD = "\${REDIS_PASSWORD:?REDIS_PASSWORD is required}";
        } // lib.optionalAttrs proxy.enable {
          HTTP_PROXY = "http://gluetun:8888";
          HTTPS_PROXY = "http://gluetun:8888";
          NO_PROXY = "postgres,redis,${proxy.noProxy}";
        };
        depends_on = {
          postgres.condition = "service_healthy";
          redis.condition = "service_healthy";
        };
        ports = [ "127.0.0.1:3333:3333" ];
        networks = [ "default" ] ++ lib.optional proxy.enable "arr";
      };
    };
    networks = {
      default = { };
    } // lib.optionalAttrs proxy.enable {
      arr = {
        external = true;
        name = "arr_default";
      };
    };
  });
  compose = pkgs.writeShellApplication {
    name = "ghostfolio";
    runtimeInputs = [ pkgs.docker pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.jq pkgs.util-linux ];
    text = ''
      fail() { echo "ghostfolio: $*" >&2; exit 1; }
      compose() {
        local args=(docker compose --project-name ghostfolio \
          --project-directory ${lib.escapeShellArg ghostfolioDirectory} \
          --env-file ${lib.escapeShellArg secretsFile} \
          -f ${composeFile})
        if [ -f ${lib.escapeShellArg imageLock} ]; then args+=(-f ${lib.escapeShellArg imageLock}); fi
        local operation_timeout=10s
        case "''${1:-}" in
          up) operation_timeout=300s ;;
          exec) operation_timeout=1800s ;;
        esac
        timeout "$operation_timeout" "''${args[@]}" "$@"
      }

      write_import_state() {
        local next
        next=$(mktemp ${lib.escapeShellArg "${ghostfolioDirectory}/.database-import-state.XXXXXX"})
        printf '%s\n' "$1" > "$next"
        chmod 600 "$next"
        mv -f -- "$next" ${lib.escapeShellArg "${ghostfolioDirectory}/.database-import-state"}
      }

      finalize_import() {
        touch ${lib.escapeShellArg "${ghostfolioDirectory}/.database-imported"}
        if [ -e ${lib.escapeShellArg "${ghostfolioDirectory}/initial-database.sql"} ] && \
           [ ! -e ${lib.escapeShellArg "${ghostfolioDirectory}/initial-database.sql.imported"} ]; then
          mv -- ${lib.escapeShellArg "${ghostfolioDirectory}/initial-database.sql"} \
            ${lib.escapeShellArg "${ghostfolioDirectory}/initial-database.sql.imported"}
        fi
        rm -f -- ${lib.escapeShellArg "${ghostfolioDirectory}/.database-import-state"}
      }

      wait_for_postgres() {
        local deadline=$((SECONDS + 180)) state container_id
        until [ "$SECONDS" -ge "$deadline" ]; do
          if timeout 5s docker compose --project-name ghostfolio \
            --project-directory ${lib.escapeShellArg ghostfolioDirectory} \
            --env-file ${lib.escapeShellArg secretsFile} \
            -f ${composeFile} -f ${lib.escapeShellArg imageLock} \
            exec -T postgres pg_isready -U ghostfolio -d ghostfolio >/dev/null 2>&1; then
            return 0
          fi
          sleep 2
        done
        container_id=$(compose ps -q postgres 2>/dev/null || true)
        state="missing"
        if [ -n "$container_id" ]; then
          state=$(docker inspect --format '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$container_id" 2>/dev/null || echo unavailable)
        fi
        fail "PostgreSQL did not become ready within 180 seconds (container state: ''${state:-missing})"
      }

      wait_until_ready() {
        local deadline=$((SECONDS + 300)) ready service container_id state
        local services=(postgres redis ghostfolio)
        while [ "$SECONDS" -lt "$deadline" ]; do
          ready=true
          for service in "''${services[@]}"; do
            container_id=$(compose ps -q "$service" 2>/dev/null || true)
            if [ -z "$container_id" ]; then ready=false; continue; fi
            state=$(timeout 3s docker inspect --format '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$container_id" 2>/dev/null || true)
            case "$service:$state" in
              postgres:running\ healthy|redis:running\ healthy|ghostfolio:running|ghostfolio:running\ healthy) ;;
              *) ready=false ;;
            esac
          done
          if [ "$ready" = true ]; then break; fi
          sleep 2
        done
        echo "Ghostfolio readiness results:"
        for service in "''${services[@]}"; do
          container_id=$(compose ps -q "$service" 2>/dev/null || true)
          state="missing"
          if [ -n "$container_id" ]; then
            state=$(timeout 3s docker inspect --format '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$container_id" 2>/dev/null || echo unavailable)
          fi
          printf '%s: %s\n' "$service" "''${state:-missing}"
        done
        [ "$ready" = true ] || fail "services did not become ready within 300 seconds"
      }

      require_pinned_images() {
        ${preflight}/bin/ghostfolio-preflight >/dev/null
      }

      import_database() {
        local state=""
        if [ -f ${lib.escapeShellArg "${ghostfolioDirectory}/.database-imported"} ]; then return 0; fi
        if [ -f ${lib.escapeShellArg "${ghostfolioDirectory}/.database-import-state"} ]; then
          state=$(cat ${lib.escapeShellArg "${ghostfolioDirectory}/.database-import-state"})
        fi
        case "$state" in
          imported) finalize_import; return 0 ;;
          importing|failed) fail "database import state is '$state'; refusing a blind retry. Restore a fresh target after reviewing the partial import" ;;
          ready|"") ;;
          *) fail "unknown database import state '$state'; inspect the target before retrying" ;;
        esac
        if [ -z "$state" ]; then write_import_state ready; fi
        compose up -d postgres redis
        wait_for_postgres
        write_import_state importing
        if ! compose exec -T postgres psql -v ON_ERROR_STOP=1 -U ghostfolio -d ghostfolio \
          < ${lib.escapeShellArg "${ghostfolioDirectory}/initial-database.sql"}; then
          write_import_state failed
          fail "SQL import failed; the dump and partial database were retained, and automatic retry is blocked"
        fi
        write_import_state imported
        finalize_import
      }

      case "''${1:-}" in
        create|run|pull|start|restart)
          require_pinned_images
          ;;
      esac

      case "''${1:-}" in
        up)
          shift
          require_pinned_images
          mkdir -p ${lib.escapeShellArg ghostfolioDirectory}
          import_database
          compose up "$@"
          wait_until_ready
          ;;
        *) compose "$@" ;;
      esac
    '';
  };
  pin = pkgs.writeShellApplication {
    name = "ghostfolio-pin";
    runtimeInputs = [ pkgs.docker pkgs.coreutils pkgs.jq pkgs.util-linux ];
    text = ''
      if [ "''${1:-}" != --refresh ] || [ "$#" -ne 1 ]; then
        echo "Usage: ghostfolio-pin --refresh" >&2
        exit 2
      fi
      ${preflight}/bin/ghostfolio-preflight --allow-unpinned
      exec 9>${lib.escapeShellArg "${ghostfolioDirectory}/.images-lock"}
      flock 9
      temporary=$(mktemp ${lib.escapeShellArg "${ghostfolioDirectory}/.images.XXXXXX"})
      trap 'rm -f -- "$temporary" "$temporary.next" "$previous_temporary"' EXIT
      previous_temporary=""
      printf '{"postgresMajor":"%s","services":{}}\n' ${lib.escapeShellArg ghost.postgresMajor} > "$temporary"
      while IFS=$'\t' read -r service reference; do
        timeout 180s docker pull "$reference"
        image=$(timeout 15s docker image inspect --format '{{json .RepoDigests}}' "$reference" \
          | jq -er 'map(select(test("@sha256:[0-9a-f]{64}$"))) | .[0]')
        jq --arg service "$service" --arg image "$image" \
          '.services[$service] = {image: $image}' "$temporary" > "$temporary.next"
        mv "$temporary.next" "$temporary"
        printf '%s -> %s\n' "$service" "$image"
      done < ${imageList}

      if [ -f ${lib.escapeShellArg imageLock} ]; then
        while IFS=$'\t' read -r _service image; do
          repo=''${image%@*}
          repo=''${repo%:*}
          if ! timeout 15s docker image tag "$image" "''${repo}:gnesha-rollback"; then
            echo "ghostfolio-pin: could not retain a previous image; current image lock was not changed" >&2
            exit 1
          fi
        done < <(jq -r '.services | to_entries[] | [.key, .value.image] | @tsv' ${lib.escapeShellArg imageLock})
        previous_temporary=$(mktemp ${lib.escapeShellArg "${ghostfolioDirectory}/.images-previous.XXXXXX"})
        cp -- ${lib.escapeShellArg imageLock} "$previous_temporary"
        chmod 644 "$previous_temporary"
        mv -f -- "$previous_temporary" ${lib.escapeShellArg imageLockPrevious}
        previous_temporary=""
      fi
      chmod 644 "$temporary"
      mv -f -- "$temporary" ${lib.escapeShellArg imageLock}
    '';
  };
  update = pkgs.writeShellApplication {
    name = "ghostfolio-update";
    runtimeInputs = [ compose pin ];
    text = ''
      ghostfolio-pin --refresh
      ghostfolio up -d
    '';
  };
in
{
  options.services.gnesha.ghostfolio = {
    enable = lib.mkEnableOption "the Ghostfolio Docker stack";
    runtimeDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/ghostfolio";
      description = "Directory for persistent Ghostfolio databases and import state.";
    };
    secretsFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/ghostfolio/secrets.env";
      description = "Runtime-only Compose environment file; its contents are never read by Nix.";
    };
    postgresMajor = lib.mkOption {
      type = lib.types.str;
      default = "17";
      description = "PostgreSQL major version for the existing Ghostfolio database.";
    };
    proxy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Connect Ghostfolio to the media stack's Gluetun proxy.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8888;
      };
      noProxy = lib.mkOption {
        type = lib.types.str;
        default = "localhost,127.0.0.1,::1";
      };
    };
  };

  config = lib.mkMerge [
    { environment.systemPackages = [ preflight pin ]; }
    (lib.mkIf ghost.enable {
      assertions = [
        {
          assertion = lib.hasPrefix "/" ghost.runtimeDirectory;
          message = "services.gnesha.ghostfolio.runtimeDirectory must be absolute";
        }
        {
          assertion = lib.hasPrefix "/" ghost.secretsFile;
          message = "services.gnesha.ghostfolio.secretsFile must be absolute";
        }
        {
          assertion = builtins.match "[0-9]+" ghost.postgresMajor != null;
          message = "services.gnesha.ghostfolio.postgresMajor must contain only digits";
        }
      ];
      environment.systemPackages = [ compose update ];
      environment.etc."containers/ghostfolio-compose.json".source = composeFile;

      systemd.services.ghostfolio-compose = {
        description = "Ghostfolio Docker Compose stack";
        wantedBy = [ "multi-user.target" ];
        after = [ "docker.service" ] ++ lib.optional proxy.enable "docker-compose.service";
        requires = [ "docker.service" ] ++ lib.optional proxy.enable "docker-compose.service";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${compose}/bin/ghostfolio up -d";
          ExecStop = "${compose}/bin/ghostfolio down";
          TimeoutStartSec = 2700;
          TimeoutStopSec = 60;
        };
      };
    })
  ];
}
