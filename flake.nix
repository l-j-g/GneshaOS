{
  description = "GneshaOS — NixOS + home-manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mcp-nixos = {
      url = "github:utensils/mcp-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-colors = {
      url = "github:Misterio77/nix-colors";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      mcp-nixos,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      # This flake currently targets one architecture. Host discovery does not
      # imply support for a different kernel/platform.

      # Stable machine parameters (hostname, account, hardware, paths, ...).
      # Edit system-parameters.nix — see system-parameters.example.nix for the
      # documented template. Host identity and optional machine overrides are
      # resolved per directory below. Fall back to the example so a fresh
      # clone evaluates even before you've written your own system parameters.
      systemParameters =
        if builtins.pathExists ./system-parameters.nix then
          import ./system-parameters.nix
        else
          import ./system-parameters.example.nix;

      parameterExample = import ./system-parameters.example.nix;
      isNumber = value: builtins.isInt value || builtins.isFloat value;
      checkContractShape =
        template: value:
        if builtins.isAttrs template then
          builtins.isAttrs value
          && builtins.all (
            name: builtins.hasAttr name value && checkContractShape template.${name} value.${name}
          ) (builtins.attrNames template)
        else if builtins.isInt template then
          builtins.isInt value
        else if builtins.isFloat template then
          isNumber value
        else
          builtins.typeOf template == builtins.typeOf value;
      checkOverlayShape =
        template: value:
        builtins.isAttrs template
        && builtins.isAttrs value
        && builtins.all (
          name: builtins.hasAttr name template && checkOverlayShape template.${name} value.${name}
        ) (builtins.attrNames value)
        || (!builtins.isAttrs template && builtins.typeOf template == builtins.typeOf value);
      isAbsolutePath = value: builtins.isString value && nixpkgs.lib.hasPrefix "/" value;
      validPort = value: builtins.isInt value && value > 0 && value <= 65535;
      validateSystemParameters =
        params:
        let
          settings = params.systemSettings;
          user = params.userSettings;
          systemProxy = settings.systemProxy;
          dockerProxy = settings.dockerProxy;
          ghostfolio = settings.ghostfolio;
          airVpn = settings.airVpn;
          validProxy =
            proxy: builtins.isBool proxy.enable && validPort proxy.port && builtins.isString proxy.noProxy;
        in
        assert
          checkContractShape parameterExample params
          || throw "System parameters must include the documented fields with matching Nix types; see system-parameters.example.nix";
        assert
          builtins.match "[a-z_][a-z0-9_-]*" user.userName != null
          || throw "userSettings.userName must be a POSIX login name";
        assert
          isAbsolutePath user.homeDirectory || throw "userSettings.homeDirectory must be an absolute path";
        assert
          builtins.isString settings.timeZone && settings.timeZone != ""
          || throw "systemSettings.timeZone must be a nonempty IANA timezone";
        assert isAbsolutePath settings.flakePath || throw "systemSettings.flakePath must be absolute";
        assert
          isAbsolutePath settings.containersDirectory
          || throw "systemSettings.containersDirectory must be absolute";
        assert
          isAbsolutePath settings.arrComposePath || throw "systemSettings.arrComposePath must be absolute";
        assert
          isAbsolutePath settings.mediaMountPoint || throw "systemSettings.mediaMountPoint must be absolute";
        assert
          isAbsolutePath airVpn.configPath || throw "systemSettings.airVpn.configPath must be absolute";
        assert
          validPort airVpn.forwardedPort
          || throw "systemSettings.airVpn.forwardedPort must be between 1 and 65535";
        assert
          isAbsolutePath ghostfolio.secretsFile
          || throw "systemSettings.ghostfolio.secretsFile must be absolute";
        assert
          isNumber settings.latitude && settings.latitude >= -90 && settings.latitude <= 90
          || throw "systemSettings.latitude must be between -90 and 90";
        assert
          isNumber settings.longitude && settings.longitude >= -180 && settings.longitude <= 180
          || throw "systemSettings.longitude must be between -180 and 180";
        assert
          builtins.isInt settings.displayWidth && settings.displayWidth > 0
          || throw "systemSettings.displayWidth must be a positive integer";
        assert
          builtins.isInt settings.displayHeight && settings.displayHeight > 0
          || throw "systemSettings.displayHeight must be a positive integer";
        assert
          validProxy systemProxy && builtins.isString systemProxy.host && systemProxy.host != ""
          || throw "systemSettings.systemProxy requires a host, valid port, and noProxy string";
        assert
          validProxy dockerProxy
          || throw "systemSettings.dockerProxy requires a valid port and noProxy string when enabled";
        params;
      baseHomeVariables = import ./home/variables.nix;
      # The preference file is deliberately raw: one literal per preference with a
      # comment above it, and that comment is the description the settings editor
      # shows. Types therefore come from the literals themselves and are checked by
      # the editor; only the rules that span preferences are spelled out here.
      validHomeVariables =
        variables:
        let
          scale = builtins.tryEval (builtins.fromJSON (toString variables.displayScale));
        in
        scale.success
        && isNumber scale.value
        && scale.value > 0
        && isNumber variables.browserDefaultZoom
        && variables.browserDefaultZoom >= 0.3
        && variables.browserDefaultZoom <= 5.0
        && variables.idleDimPercent >= 0
        && variables.idleDimPercent <= 100
        && variables.idleDimSec < variables.idleLockSec
        && variables.idleLockSec < variables.idleOffSec
        && (
          variables.idleSuspendSec == null
          || variables.idleSuspendSec > variables.idleOffSec
        )
        && isAbsolutePath variables.screenshotDir
        && isAbsolutePath variables.publicKeyFile
        && !(builtins.elem variables.terminalFontFamily [ "monospace" "sans-serif" "serif" ])
        && builtins.match "[A-Za-z0-9][A-Za-z0-9._-]*" variables.hermesSshHost != null
        && builtins.all (port: builtins.isInt port && port >= 1 && port <= 65535) [
          variables.hermesLocalPort
          variables.hermesRemotePort
        ];

      hostNames = builtins.filter (
        name:
        let
          hostType = (builtins.readDir ./hosts).${name};
        in
        hostType == "directory" && !(nixpkgs.lib.hasPrefix "_" name)
      ) (builtins.attrNames (builtins.readDir ./hosts));

      hostContext =
        hostName:
        let
          hostPath = ./hosts + "/${hostName}";
          hostParamsPath = hostPath + "/system-parameters.nix";
          hostOverrides = if builtins.pathExists hostParamsPath then import hostParamsPath else { };
          # Root system parameters provide shared defaults. A host can override
          # only the values that differ on that machine.
          mergedParams = nixpkgs.lib.recursiveUpdate systemParameters hostOverrides;
          hostParams = validateSystemParameters (
            mergedParams
            // {
              systemSettings = mergedParams.systemSettings // {
                inherit hostName;
              };
            }
          );
          hostVariablesPath = hostPath + "/home-variables.nix";
          hostVariables = if builtins.pathExists hostVariablesPath then import hostVariablesPath else { };
          variables = nixpkgs.lib.recursiveUpdate baseHomeVariables hostVariables;
          username = hostParams.userSettings.userName;
        in
        assert
          checkOverlayShape baseHomeVariables hostVariables
          || throw "${hostName}/home-variables.nix must use known Home Manager preference names and matching types";
        assert
          validHomeVariables variables
          || throw "Home Manager preferences need a positive scale, zoom between 0.3 and 5.0, idle timers in increasing order, absolute paths, a real font family, a valid SSH alias, and ports in 1-65535";
        {
          inherit
            hostName
            hostPath
            hostParams
            hostVariables
            username
            ;
        };

      homeConfiguration =
        hostName:
        let
          context = hostContext hostName;
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit inputs;
            hostVariables = context.hostVariables;
            params = context.hostParams;
          };
          modules = [ ./home ];
        };

      hostConfiguration =
        hostName: parameterOverrides:
        {
          extraModules ? [ ],
        }:
        let
          context = hostContext hostName;
          hostParams =
            if parameterOverrides == null then
              context.hostParams
            else
              validateSystemParameters (nixpkgs.lib.recursiveUpdate context.hostParams parameterOverrides);
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            inherit (context) username hostName;
            inherit hostParams;
            params = hostParams;
          };
          modules = [ context.hostPath ] ++ extraModules;
        };
      checkPkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      hostCheck = parameterOverrides: hostConfiguration "cf-fv1" parameterOverrides { };
      hostCheckGhostfolioProxyOff = hostCheck {
        systemSettings = {
          systemProxy.enable = false;
          dockerProxy.enable = false;
          ghostfolio.enable = true;
          airVpn.enable = true;
          airVpn.autostart = false;
        };
      };
      hostCheckGhostfolioProxyOn = hostCheck {
        systemSettings = {
          dockerProxy.enable = true;
          ghostfolio.enable = true;
        };
      };
      ghostfolioFixtureRoot = "/build/gnesha-ghostfolio-import-check";
      ghostfolioDockerStub = checkPkgs.writeShellScriptBin "docker" ''
        set -eu
        printf '%s\n' "$*" >> "$GHOSTFOLIO_FIXTURE_ROOT/docker-calls"
        case "$1" in
          info) exit 0 ;;
          pull)
            if [ "''${GHOSTFOLIO_PULL_FAIL:-0}" = 1 ]; then
              count_file="$GHOSTFOLIO_FIXTURE_ROOT/pull-count"
              count=0
              if [ -f "$count_file" ]; then read -r count < "$count_file"; fi
              count=$((count + 1))
              printf '%s\n' "$count" > "$count_file"
              if [ "$count" -eq 2 ]; then echo 'synthetic registry unavailable' >&2; exit 42; fi
            fi
            exit 0
            ;;
          image)
            case "$2" in
              inspect)
                image="''${@: -1}"
                printf '["%s@sha256:%064d"]\n' "$image" 0
                ;;
              tag) exit 0 ;;
              *) echo "unexpected Docker image fixture invocation: $*" >&2; exit 73 ;;
            esac
            ;;
          compose)
            case " $* " in
              *" config --quiet "*) exit 0 ;;
              *" exec -T postgres pg_isready "*)
                if [ "''${GHOSTFOLIO_READY_FAIL:-0}" = 1 ]; then exit 42; fi
                exit 0
                ;;
              *" exec -T postgres psql "*)
                cat > "$GHOSTFOLIO_FIXTURE_ROOT/psql-input"
                if [ "''${GHOSTFOLIO_INTERRUPT:-}" = sql-consumed ]; then
                  kill -KILL "''${GHOSTFOLIO_MAIN_PID:?synthetic Ghostfolio PID was not provided}"
                fi
                if [ "''${GHOSTFOLIO_PSQL_FAIL:-0}" = 1 ]; then exit 42; fi
                exit 0
                ;;
              *" ps -q postgres "*) echo postgres-container ;;
              *" ps -q redis "*) echo redis-container ;;
              *" ps -q ghostfolio "*) echo ghostfolio-container ;;
              *" up "*)
                if [ "''${GHOSTFOLIO_INTERRUPT:-}" = before-import ]; then
                  kill -KILL "''${GHOSTFOLIO_MAIN_PID:?synthetic Ghostfolio PID was not provided}"
                  exit 0
                fi
                case " $* " in
                  *" up -d postgres redis "*)
                    printf '17\n' > "$GHOSTFOLIO_FIXTURE_ROOT/ghostfolio/postgres/PG_VERSION"
                    ;;
                esac
                exit 0
                ;;
              *) echo "unexpected docker compose fixture invocation: $*" >&2; exit 70 ;;
            esac
            ;;
          inspect)
            case " $* " in
              *" postgres-container "*) echo 'running healthy' ;;
              *" redis-container "*) echo 'running healthy' ;;
              *" ghostfolio-container "*)
                if [ "''${GHOSTFOLIO_SERVICES_UNREADY:-0}" = 1 ]; then echo 'running starting'; else echo running; fi
                ;;
              *) echo "unexpected docker inspect fixture invocation: $*" >&2; exit 71 ;;
            esac
            ;;
          *) echo "unexpected docker fixture invocation: $*" >&2; exit 72 ;;
        esac
      '';
      ghostfolioFixtureConfig =
        hostConfiguration "cf-fv1"
          {
            systemSettings = {
              containersDirectory = ghostfolioFixtureRoot;
              dockerProxy.enable = false;
              ghostfolio = {
                enable = true;
                secretsFile = "${ghostfolioFixtureRoot}/ghostfolio/secrets.env";
              };
            };
          }
          {
            extraModules = [
              {
                nixpkgs.overlays = [
                  (final: prev: { docker = ghostfolioDockerStub; })
                ];
              }
            ];
          };
      ghostfolioFixturePackage = builtins.head (
        builtins.filter (
          package: package.name == "ghostfolio"
        ) ghostfolioFixtureConfig.config.environment.systemPackages
      );
      ghostfolioPinFixturePackage = builtins.head (
        builtins.filter (
          package: package.name == "ghostfolio-pin"
        ) ghostfolioFixtureConfig.config.environment.systemPackages
      );
      ghostfolioImportRecoveryCheck =
        checkPkgs.runCommand "gnesha-ghostfolio-import-recovery-check"
          {
            nativeBuildInputs = [
              checkPkgs.bash
              checkPkgs.coreutils
              checkPkgs.gnugrep
              checkPkgs.jq
            ];
          }
          ''
            bash ${./checks/ghostfolio-import-recovery-stubs.sh} \
              ${ghostfolioFixturePackage}/bin/ghostfolio \
              ${ghostfolioPinFixturePackage}/bin/ghostfolio-pin \
              ${ghostfolioFixtureRoot}
            touch "$out"
          '';
      arrFixtureRoot = "/build/gnesha-arr-wrapper-check";
      arrDockerStub = checkPkgs.writeShellScriptBin "docker" ''
        set -eu
        printf '%s\n' "$*" >> "$GNESHA_ARR_FIXTURE_LOG"
        case "$1" in
          container|compose) exit 0 ;;
          *) echo "unexpected arr fixture Docker command: $*" >&2; exit 70 ;;
        esac
      '';
      arrFixtureConfig =
        hostConfiguration "cf-fv1"
          {
            systemSettings.arrComposePath = "${arrFixtureRoot}/arr/docker-compose.yml";
          }
          {
            extraModules = [
              {
                nixpkgs.overlays = [
                  (final: prev: { docker = arrDockerStub; })
                ];
              }
            ];
          };
      arrFixturePackage = builtins.head (
        builtins.filter (package: package.name == "arr") arrFixtureConfig.config.environment.systemPackages
      );
      arrWrapperCheck =
        checkPkgs.runCommand "gnesha-arr-wrapper-check"
          {
            nativeBuildInputs = [
              checkPkgs.bash
              checkPkgs.coreutils
              checkPkgs.gnugrep
            ];
          }
          ''
            bash ${./checks/arr-wrapper-stubs.sh} \
              ${arrFixturePackage}/bin/arr \
              ${arrFixtureRoot}
            touch "$out"
          '';
      arrRuntimeFixtureRoot = "/build/gnesha-arr-runtime-check";
      arrRuntimeDockerStub = checkPkgs.writeShellScriptBin "docker" ''
        set -eu
        printf '%s\n' "$*" >> "$GNESHA_ARR_FIXTURE_LOG"
        case "$1 $2" in
          "container inspect")
            service="''${@: -1}"
            if [ "$service" = watchtower ]; then exit 1; fi
            case "''${GNESHA_ARR_FIXTURE_MODE:-}" in
              delayed-ready)
                count_file="$GNESHA_ARR_FIXTURE_STATE/$service.count"
                count=0
                if [ -f "$count_file" ]; then read -r count < "$count_file"; fi
                count=$((count + 1))
                printf '%s\n' "$count" > "$count_file"
                if [ "$count" -lt 2 ]; then echo 'running starting'; else echo 'running healthy'; fi
                ;;
              permanently-unready) echo 'running unhealthy' ;;
              *) echo 'running healthy' ;;
            esac
            ;;
          "pull "*)
            if [ "''${GNESHA_ARR_FIXTURE_MODE:-}" = pull-fail ]; then
              count_file="$GNESHA_ARR_FIXTURE_STATE/pulls.count"
              count=0
              if [ -f "$count_file" ]; then read -r count < "$count_file"; fi
              count=$((count + 1))
              printf '%s\n' "$count" > "$count_file"
              if [ "$count" -eq 2 ]; then echo 'synthetic pull failure' >&2; exit 42; fi
            fi
            ;;
          "image inspect")
            image="''${@: -1}"
            printf '["%s@sha256:%064d"]\n' "$image" 0
            ;;
          "image tag") ;;
          "stop "*|"rm "*) ;;
          *) echo "unexpected Docker fixture invocation: $*" >&2; exit 70 ;;
        esac
      '';
      arrRuntimeFixtureConfig =
        hostConfiguration "cf-fv1"
          {
            systemSettings.arrComposePath = "${arrRuntimeFixtureRoot}/arr/docker-compose.yml";
          }
          {
            extraModules = [
              {
                nixpkgs.overlays = [
                  (final: prev: { docker = arrRuntimeDockerStub; })
                ];
              }
            ];
          };
      arrRuntimePackage = name:
        builtins.head (
          builtins.filter (package: package.name == name) arrRuntimeFixtureConfig.config.environment.systemPackages
        );
      arrRuntimePinPackage = arrRuntimePackage "arr-pin";
      arrRuntimeUpdatePackage = arrRuntimePackage "arr-update";
      arrRuntimeStubCheck =
        checkPkgs.runCommand "gnesha-arr-runtime-stubs-check"
          {
            nativeBuildInputs = [
              checkPkgs.bash
              checkPkgs.coreutils
              checkPkgs.gnugrep
              checkPkgs.jq
            ];
          }
          ''
            arrWaitReady=$(grep -oE '/nix/store/[^[:space:]]*/bin/arr-wait-ready' ${arrRuntimeUpdatePackage}/bin/arr-update | head -n 1)
            test -x "$arrWaitReady"
            bash ${./checks/arr-runtime-stubs.sh} \
              ${arrRuntimePinPackage}/bin/arr-pin \
              "$arrWaitReady" \
              "${arrRuntimeFixtureRoot}"
            touch "$out"
          '';
      configurationCombinationChecks =
        let
          base = hostCheck null;
          home = (homeConfiguration "cf-fv1").config;
          arrUnit = base.config.systemd.services.docker-compose;
          calcurseCondition = home.systemd.user.services.calcurse-daemon.Service.ExecCondition;
          forwardedPort = systemParameters.systemSettings.airVpn.forwardedPort;
          mediaComposeFile = base.config.environment.etc."arr/compose.json".source;
          ghostProxyOff = hostCheckGhostfolioProxyOff.config;
          ghostProxyOn = hostCheckGhostfolioProxyOn.config;
          dockerUnitUnset = base.config.systemd.services.docker.serviceConfig.UnsetEnvironment;
          nixDaemonUnitUnset = base.config.systemd.services.nix-daemon.serviceConfig.UnsetEnvironment;
        in
        assert base.config.services.gnesha.airvpn.enable;
        assert nixpkgs.lib.hasInfix "calcurse-daemon-enabled" calcurseCondition;
        assert nixpkgs.lib.hasInfix
          "${home.home.homeDirectory}/.config/sway/scripts/calcurse-daemon-enabled"
          calcurseCondition;
        assert !base.config.services.gnesha.airvpn.autostart;
        assert !base.config.services.gnesha.ghostfolio.enable;
        assert base.config.services.gnesha.ghostfolio.secretsFile
          == "${base.config.services.gnesha.ghostfolio.runtimeDirectory}/secrets.env";
        assert base.config.networking.proxy.httpProxy == null;
        assert !(builtins.elem forwardedPort base.config.networking.firewall.allowedTCPPorts);
        assert !(builtins.elem forwardedPort base.config.networking.firewall.allowedUDPPorts);
        assert !(builtins.elem "multi-user.target" arrUnit.after);
        assert !(builtins.elem "multi-user.target" ghostProxyOn.systemd.services.ghostfolio-compose.after);
        assert builtins.all (name: builtins.elem name dockerUnitUnset) [
          "http_proxy"
          "https_proxy"
          "all_proxy"
          "HTTP_PROXY"
          "HTTPS_PROXY"
          "ALL_PROXY"
        ];
        assert builtins.all (name: builtins.elem name nixDaemonUnitUnset) [
          "http_proxy"
          "https_proxy"
          "all_proxy"
          "HTTP_PROXY"
          "HTTPS_PROXY"
          "ALL_PROXY"
        ];
        assert ghostProxyOff.services.gnesha.ghostfolio.enable;
        assert ghostProxyOn.services.gnesha.ghostfolio.enable;
        checkPkgs.runCommand "gnesha-configuration-combinations"
          {
            nativeBuildInputs = [ checkPkgs.jq ];
          }
          ''
            cp ${ghostProxyOff.environment.etc."containers/ghostfolio-compose.json".source} proxy-off.json
            cp ${ghostProxyOn.environment.etc."containers/ghostfolio-compose.json".source} proxy-on.json
            cp ${mediaComposeFile} media.json
            jq -e '.services.ghostfolio.environment.HTTP_PROXY == null and .services.ghostfolio.environment.HTTPS_PROXY == null' proxy-off.json >/dev/null
            jq -e '.services.ghostfolio.environment.HTTP_PROXY == "http://gluetun:8888" and .services.ghostfolio.environment.HTTPS_PROXY == "http://gluetun:8888"' proxy-on.json >/dev/null
            jq -e --arg port "${toString forwardedPort}" '
              (.services.gluetun.environment | index("FIREWALL_VPN_INPUT_PORTS=" + $port)) != null and
              ([.services.gluetun.ports[] | select(test("(^|:)" + $port + "([:/]|$)"))] | length == 0)
            ' media.json >/dev/null
            touch "$out"
          '';
      sourceScriptCheck =
        checkPkgs.runCommand "gnesha-source-and-helper-checks"
          {
            nativeBuildInputs = [
              checkPkgs.bash
              checkPkgs.coreutils
              checkPkgs.fish
              checkPkgs.gawk
              checkPkgs.gnugrep
              checkPkgs.gnused
              checkPkgs.jq
              checkPkgs.util-linux
            ];
          }
          ''
            for script in \
              ${./home/shell/airvpn-profile} \
              ${./home/desktop/sway/scripts/vpn-toggle} \
              ${./home/desktop/sway/scripts/calcurse-daemon-enabled} \
              ${./home/desktop/sway/scripts/recorder.sh} \
              ${./home/desktop/sway/scripts/sway-help} \
              ${./hosts/cf-fv1/services/update-network-ready.sh} \
              ${./checks/update-network-readiness-stubs.sh} \
              ${./checks/arr-wrapper-stubs.sh}; do
              bash -n "$script"
            done
            bash -n ${./home/shell/lock-readiness.sh} ${./checks/lock-readiness-stubs.sh}
            fish --no-execute ${./home/shell/nix-workflow.fish}
            fish --no-execute ${./checks/nix-workflow-status.fish}
            fish ${./checks/nix-workflow-status.fish} ${./home/shell/nix-workflow.fish}
            bash ${./checks/activation-helper-stubs.sh} ${./home/shell/activation-state.sh}
            bash ${./checks/update-network-readiness-stubs.sh} ${./hosts/cf-fv1/services/update-network-ready.sh}
            bash ${./checks/calcurse-daemon-optin-stubs.sh} ${./home/desktop/sway/scripts/calcurse-daemon-enabled}
            bash ${./checks/vpn-toggle-stubs.sh} ${./home/desktop/sway/scripts/vpn-toggle}
            bash ${./checks/lock-readiness-stubs.sh} ${./home/shell/lock-readiness.sh}
            touch "$out"
          '';
      settingsEditorCheck =
        checkPkgs.runCommand "gnesha-settings-editor-check"
          {
            nativeBuildInputs = [
              checkPkgs.python3
              checkPkgs.nix
            ];
          }
          ''
            cd ${./.}
            # nix-instantiate keeps state outside the store, so point it at the
            # build directory: the tests evaluate throwaway preference files.
            export HOME="$TMPDIR/home" NIX_STATE_DIR="$TMPDIR/state"
            mkdir -p "$HOME" "$NIX_STATE_DIR"
            PYTHONDONTWRITEBYTECODE=1 python3 checks/rofi-settings.py home/desktop/rofi/scripts/settings.py
            touch "$out"
          '';
      desktopHelperStubCheck =
        checkPkgs.runCommand "gnesha-desktop-helper-stub-checks"
          {
            nativeBuildInputs = [
              checkPkgs.bash
              checkPkgs.coreutils
              checkPkgs.gnugrep
              checkPkgs.gnused
              checkPkgs.stdenv.cc
            ];
          }
          ''
            bash ${./checks/desktop-helper-stubs.sh} \
              ${./home/desktop/sway/scripts/recorder.sh} \
              ${./home/desktop/sway/scripts/sway-help} \
              /build/gnesha-desktop-helper-check \
              ${./checks/desktop-wf-recorder-stub.c}
            touch "$out"
          '';
    in
    {
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;
      checks.${system} = {
        inherit
          configurationCombinationChecks
          sourceScriptCheck
          settingsEditorCheck
          desktopHelperStubCheck
          ghostfolioImportRecoveryCheck
          arrWrapperCheck
          arrRuntimeStubCheck
          ;
      };

      # User-level configuration is deliberately separate from the system
      # output. Desktop/theme changes can use `nh home switch` without
      # rebuilding the kernel, hardware, and machine services.
      homeConfigurations = builtins.listToAttrs (
        map (
          hostName:
          let
            context = hostContext hostName;
          in
          {
            name = "${context.username}@${hostName}";
            value = homeConfiguration hostName;
          }
        ) hostNames
      );
      nixosConfigurations = builtins.listToAttrs (
        map (hostName: {
          name = hostName;
          value = hostConfiguration hostName null { };
        }) hostNames
      );
    };
}
