# Run Ghostfolio and its persistent PostgreSQL and Redis services with Docker
# Compose. Keep migration preflight available while the feature is disabled.
{ config, lib, pkgs, ... }:

let
  ghost = config.services.gnesha.ghostfolio;
  ghostfolioDirectory = ghost.runtimeDirectory;
  secretsFile = ghost.secretsFile;
  proxy = ghost.proxy;
  preflight = pkgs.writeShellApplication {
    name = "ghostfolio-preflight";
    runtimeInputs = [ pkgs.docker pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnused ];
    text = ''
      fail() { echo "ghostfolio-preflight: $*" >&2; exit 1; }

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
      if [ -e "$marker" ]; then
        [ -s "$database/PG_VERSION" ] || fail "import marker exists but PostgreSQL data is missing; inspect the data before retrying"
        actual_major=$(cat "$database/PG_VERSION")
        [ "$actual_major" = ${lib.escapeShellArg ghost.postgresMajor} ] \
          || fail "PostgreSQL data is major $actual_major but the configured image is major ${ghost.postgresMajor}"
      else
        if [ -d "$database" ] && [ -n "$(find "$database" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
          fail "PostgreSQL data already exists without a completion marker; inspect or restore a fresh target before importing"
        fi
        [ -s "$import" ] || fail "SQL dump is missing or empty: ${ghostfolioDirectory}/initial-database.sql"
        dump_major=$(sed -nE 's/^-- Dumped from database version ([0-9]+)\..*/\1/p' "$import" | head -n 1)
        [ -n "$dump_major" ] || fail "SQL dump has no pg_dump source-version header; verify its source and export method"
        [ "$dump_major" = ${lib.escapeShellArg ghost.postgresMajor} ] \
          || fail "SQL dump source major is $dump_major but the configured PostgreSQL image is major ${ghost.postgresMajor}"
      fi

      docker info >/dev/null 2>&1 || fail "Docker daemon is unavailable or permission was denied"
      ${lib.optionalString proxy.enable ''
        docker network inspect arr_default >/dev/null 2>&1 \
          || fail "Docker network arr_default is missing; start the media stack before Ghostfolio"
      ''}
      docker compose --project-name ghostfolio \
        --project-directory ${lib.escapeShellArg ghostfolioDirectory} \
        --env-file ${lib.escapeShellArg secretsFile} \
        -f ${composeFile} config --quiet \
        || fail "Compose configuration or runtime prerequisites are invalid"
      echo "ghostfolio-preflight: runtime prerequisites pass for PostgreSQL major ${ghost.postgresMajor}; no data was changed"
    '';
  };
  composeFile = pkgs.writeText "ghostfolio-compose.json" (builtins.toJSON {
    name = "ghostfolio";
    services = {
      postgres = {
        image = "docker.io/library/postgres:${ghost.postgresMajor}-alpine";
        pull_policy = "missing";
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
        image = "docker.io/library/redis:7-alpine";
        pull_policy = "missing";
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
        image = "docker.io/ghostfolio/ghostfolio:latest";
        pull_policy = "missing";
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
    runtimeInputs = [ pkgs.docker pkgs.coreutils ];
    text = ''
      compose() {
        docker compose --project-name ghostfolio \
          --project-directory ${lib.escapeShellArg ghostfolioDirectory} \
          --env-file ${lib.escapeShellArg secretsFile} \
          -f ${composeFile} "$@"
      }

      case "''${1:-}" in
        up)
          shift
          ${preflight}/bin/ghostfolio-preflight
          mkdir -p ${lib.escapeShellArg ghostfolioDirectory}
          if [ ! -e ${lib.escapeShellArg "${ghostfolioDirectory}/.database-imported"} ]; then
            if [ ! -s ${lib.escapeShellArg "${ghostfolioDirectory}/initial-database.sql"} ]; then
              echo "Ghostfolio database import is missing; export the existing database before activation." >&2
              exit 1
            fi
            compose up -d postgres redis
            until docker compose --project-name ghostfolio \
              --project-directory ${lib.escapeShellArg ghostfolioDirectory} \
              --env-file ${lib.escapeShellArg secretsFile} -f ${composeFile} \
              exec -T postgres pg_isready -U ghostfolio -d ghostfolio >/dev/null 2>&1; do
              sleep 2
            done
            compose exec -T postgres psql -v ON_ERROR_STOP=1 -U ghostfolio -d ghostfolio \
              < ${lib.escapeShellArg "${ghostfolioDirectory}/initial-database.sql"}
            touch ${lib.escapeShellArg "${ghostfolioDirectory}/.database-imported"}
            mv ${lib.escapeShellArg "${ghostfolioDirectory}/initial-database.sql"} \
              ${lib.escapeShellArg "${ghostfolioDirectory}/initial-database.sql.imported"}
          fi
          compose up -d "$@"
          ;;
        *) compose "$@" ;;
      esac
    '';
  };
  update = pkgs.writeShellApplication {
    name = "ghostfolio-update";
    runtimeInputs = [ compose ];
    text = ''
      ghostfolio pull
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
    { environment.systemPackages = [ preflight ]; }
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
          TimeoutStartSec = 300;
          TimeoutStopSec = 60;
        };
      };
    })
  ];
}
