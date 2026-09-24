# Run Ghostfolio and its persistent PostgreSQL and Redis services with Docker
# Compose. The SQL import is prepared before replacing the native service.
{ lib, pkgs, params, ... }:

let
  containersDirectory = params.systemSettings.containersDirectory;
  ghostfolioDirectory = "${containersDirectory}/ghostfolio";
  secretsFile = "/home/lg/src/ghostfolio/secrets.env";
  proxy = params.systemSettings.dockerProxy or { enable = false; };
  composeFile = pkgs.writeText "ghostfolio-compose.json" (builtins.toJSON {
    name = "ghostfolio";
    services = {
      postgres = {
        image = "docker.io/library/postgres:${params.systemSettings.ghostfolioPostgresMajor or "17"}-alpine";
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
}
