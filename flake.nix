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
      validHomeVariables =
        variables:
        let
          scale =
            if builtins.isString variables.displayScale then
              builtins.tryEval (builtins.fromJSON variables.displayScale)
            else
              {
                success = false;
                value = null;
              };
          idleValues = [
            variables.idleDimSec
            variables.idleLockSec
            variables.idleOffSec
            variables.idleSuspendSec
          ];
        in
        builtins.isInt variables.terminalFontSize
        && variables.terminalFontSize > 0
        && builtins.isInt variables.stackedViewFontSize
        && variables.stackedViewFontSize > 0
        && scale.success
        && isNumber scale.value
        && scale.value > 0
        && isNumber variables.browserDefaultZoom
        && variables.browserDefaultZoom > 0
        && builtins.all (value: builtins.isInt value && value > 0) idleValues
        && variables.idleDimSec < variables.idleLockSec
        && variables.idleLockSec < variables.idleOffSec
        && variables.idleOffSec < variables.idleSuspendSec
        && builtins.isInt variables.idleDimPercent
        && variables.idleDimPercent >= 0
        && variables.idleDimPercent <= 100
        && isAbsolutePath variables.screenshotDir
        && isAbsolutePath variables.publicKeyFile
        && builtins.isBool variables.hermesMacTunnelEnable
        && builtins.isString variables.hermesSshHost
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
          || throw "Home Manager preferences need positive font/scale/zoom values, absolute paths, and idleDim < idleLock < idleOff < idleSuspend";
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
          modules = [
            context.hostPath
          ];
        };
      checkPkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      hostCheck = parameterOverrides: hostConfiguration "cf-fv1" parameterOverrides;
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
      configurationCombinationChecks =
        let
          base = hostCheck null;
          arrUnit = base.config.systemd.services.docker-compose;
          ghostProxyOff = hostCheckGhostfolioProxyOff.config;
          ghostProxyOn = hostCheckGhostfolioProxyOn.config;
          dockerUnitUnset = base.config.systemd.services.docker.serviceConfig.UnsetEnvironment;
          nixDaemonUnitUnset = base.config.systemd.services.nix-daemon.serviceConfig.UnsetEnvironment;
        in
        assert base.config.services.gnesha.airvpn.enable;
        assert !base.config.services.gnesha.airvpn.autostart;
        assert !base.config.services.gnesha.ghostfolio.enable;
        assert base.config.networking.proxy.httpProxy == null;
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
            jq -e '.services.ghostfolio.environment.HTTP_PROXY == null and .services.ghostfolio.environment.HTTPS_PROXY == null' proxy-off.json >/dev/null
            jq -e '.services.ghostfolio.environment.HTTP_PROXY == "http://gluetun:8888" and .services.ghostfolio.environment.HTTPS_PROXY == "http://gluetun:8888"' proxy-on.json >/dev/null
            touch "$out"
          '';
      sourceScriptCheck =
        checkPkgs.runCommand "gnesha-source-script-syntax"
          {
            nativeBuildInputs = [
              checkPkgs.bash
            ];
          }
          ''
            for script in \
              ${./home/shell/airvpn-profile} \
              ${./home/desktop/sway/scripts/vpn-toggle} \
              ${./home/desktop/sway/scripts/recorder.sh} \
              ${./home/desktop/sway/scripts/sway-help}; do
              bash -n "$script"
            done
            touch "$out"
          '';
    in
    {
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;
      checks.${system} = {
        inherit configurationCombinationChecks sourceScriptCheck;
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
          value = hostConfiguration hostName null;
        }) hostNames
      );
    };
}
