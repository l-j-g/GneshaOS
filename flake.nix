{
  description = "GneshaOS — NixOS + home-manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    llm-agents.url = "github:numtide/llm-agents.nix";
    nix-skills.url = "github:olafkfreund/nix-skills";
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
      isAbsolutePath = value: builtins.isString value && nixpkgs.lib.hasPrefix "/" value;
      validPort = value: builtins.isInt value && value > 0 && value <= 65535;
      validateSystemParameters =
        params:
        let
          settings = params.systemSettings;
          user = params.userSettings;
          systemProxy = settings.systemProxy;
          dockerProxy = settings.dockerProxy;
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
          isAbsolutePath settings.arrComposePath || throw "systemSettings.arrComposePath must be absolute";
        assert
          isAbsolutePath settings.mediaMountPoint || throw "systemSettings.mediaMountPoint must be absolute";
        assert
          isAbsolutePath airVpn.configPath || throw "systemSettings.airVpn.configPath must be absolute";
        assert
          validPort airVpn.forwardedPort
          || throw "systemSettings.airVpn.forwardedPort must be between 1 and 65535";
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
      # shows. The shared schema supplies types and ranges; the same validator
      # checks preferences here, in Home Manager, and in the Settings editor.
      validHomeVariables = variables: import ./home/preferences/validate.nix { inherit variables; };

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
          validHomeVariables variables
          || throw "Home Manager preferences must match home/preferences/schema.nix and the shared font and idle timer constraints";
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
            overlays = [ ];
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
        overlays = [ ];
      };
    in
    {
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;
      checks.${system} = import ./checks {
        inherit
          checkPkgs
          nixpkgs
          hostConfiguration
          homeConfiguration
          systemParameters
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
