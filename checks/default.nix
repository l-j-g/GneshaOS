# Non-activating configuration and helper checks, exported by flake.nix.
{
  checkPkgs,
  nixpkgs,
  hostConfiguration,
  homeConfiguration,
  systemParameters,
}:

let
  hostCheck = parameterOverrides: hostConfiguration "cf-fv1" parameterOverrides { };
  hostCheckProxyOff = hostCheck {
    systemSettings = {
      systemProxy.enable = false;
      dockerProxy.enable = false;
      airVpn.enable = true;
      airVpn.autostart = false;
    };
  };
  hostCheckProxyOn = hostCheck {
    systemSettings.dockerProxy.enable = true;
  };
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
        bash ${./arr-wrapper-stubs.sh} \
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
  arrRuntimePackage =
    name:
    builtins.head (
      builtins.filter (
        package: package.name == name
      ) arrRuntimeFixtureConfig.config.environment.systemPackages
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
        bash ${./arr-runtime-stubs.sh} \
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
      proxyOff = hostCheckProxyOff.config;
      proxyOn = hostCheckProxyOn.config;
      dockerUnitUnset = base.config.systemd.services.docker.serviceConfig.UnsetEnvironment;
      nixDaemonUnitUnset = base.config.systemd.services.nix-daemon.serviceConfig.UnsetEnvironment;
    in
    assert base.config.services.gnesha.airvpn.enable;
    assert nixpkgs.lib.hasInfix "calcurse-daemon-enabled" calcurseCondition;
    assert nixpkgs.lib.hasInfix
      "${home.home.homeDirectory}/.config/sway/scripts/calcurse-daemon-enabled"
      calcurseCondition;
    assert !base.config.services.gnesha.airvpn.autostart;
    assert base.config.networking.proxy.httpProxy == null;
    assert !(builtins.elem forwardedPort base.config.networking.firewall.allowedTCPPorts);
    assert !(builtins.elem forwardedPort base.config.networking.firewall.allowedUDPPorts);
    assert !(builtins.elem "multi-user.target" arrUnit.after);
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
    checkPkgs.runCommand "gnesha-configuration-combinations"
      {
        nativeBuildInputs = [ checkPkgs.jq ];
      }
      ''
        cp ${proxyOff.environment.etc."arr/compose.json".source} proxy-off.json
        cp ${proxyOn.environment.etc."arr/compose.json".source} proxy-on.json
        jq -e '.services.gluetun.environment | index("HTTPPROXY=on") == null' proxy-off.json >/dev/null
        jq -e '.services.gluetun.environment | index("HTTPPROXY=on") != null' proxy-on.json >/dev/null
        cp ${mediaComposeFile} media.json
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
          ${../home/shell/airvpn-profile} \
          ${../home/desktop/sway/scripts/vpn-toggle} \
          ${../home/desktop/sway/scripts/calcurse-daemon-enabled} \
          ${../home/desktop/sway/scripts/recorder.sh} \
          ${../hosts/cf-fv1/services/update-network-ready.sh} \
          ${./update-network-readiness-stubs.sh} \
          ${./arr-wrapper-stubs.sh}; do
          bash -n "$script"
        done
        bash -n ${../home/shell/lock-readiness.sh} ${./lock-readiness-stubs.sh}
        fish --no-execute ${../home/shell/nix-workflow.fish}
        fish --no-execute ${./nix-workflow-status.fish}
        fish ${./nix-workflow-status.fish} ${../home/shell/nix-workflow.fish}
        bash ${./activation-helper-stubs.sh} ${../home/shell/activation-state.sh}
        bash ${./rebuild-cache-stubs.sh} ${../home/shell/activation-state.sh}
        bash ${./build-monitor-stubs.sh} ${../home/shell/build-monitor}
        bash ${./update-network-readiness-stubs.sh} ${../hosts/cf-fv1/services/update-network-ready.sh}
        bash ${./calcurse-daemon-optin-stubs.sh} ${../home/desktop/sway/scripts/calcurse-daemon-enabled}
        bash ${./vpn-toggle-stubs.sh} ${../home/desktop/sway/scripts/vpn-toggle}
        bash ${./lock-readiness-stubs.sh} ${../home/shell/lock-readiness.sh}
        touch "$out"
      '';
  letsnoteFanCheck =
    checkPkgs.runCommand "gnesha-letsnote-fan-check"
      { nativeBuildInputs = [ checkPkgs.python3 ]; }
      ''
        cd ${../.}
        PYTHONDONTWRITEBYTECODE=1 python3 checks/letsnote-fan.py
        touch "$out"
      '';
  settingsEditorCheck =
    checkPkgs.runCommand "gnesha-settings-editor-check"
      {
        nativeBuildInputs = [
          checkPkgs.python3
          checkPkgs.nix
          checkPkgs.bash
          checkPkgs.jq
          checkPkgs.gawk
          checkPkgs.ripgrep
          checkPkgs.coreutils
          checkPkgs.gnused
          checkPkgs.util-linux
          checkPkgs.fontconfig
        ];
      }
      ''
        cd ${../.}
        # nix-instantiate keeps state outside the store, so point it at the
        # build directory: the tests evaluate throwaway preference files.
        export HOME="$TMPDIR/home" NIX_STATE_DIR="$TMPDIR/state"
        mkdir -p "$HOME" "$NIX_STATE_DIR"
        PYTHONDONTWRITEBYTECODE=1 python3 checks/rofi-settings.py home/desktop/rofi/scripts/settings.sh
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
        bash ${./desktop-helper-stubs.sh} \
          ${../home/desktop/sway/scripts/recorder.sh} \
          /build/gnesha-desktop-helper-check \
          ${./desktop-wf-recorder-stub.c}
        touch "$out"
      '';
in
{
  inherit
    configurationCombinationChecks
    sourceScriptCheck
    settingsEditorCheck
    letsnoteFanCheck
    desktopHelperStubCheck
    arrWrapperCheck
    arrRuntimeStubCheck
    ;
}
