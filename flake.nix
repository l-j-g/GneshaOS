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

      # Shared consumer/user defaults (username, resolution, scaling, paths,
      # ...). Edit params.nix — see params.example.nix for the fully
      # documented template. Host identity and optional machine overrides are
      # resolved per directory below. Fall back to the example so a fresh
      # clone evaluates even before you've written your own params.nix.
      params = if builtins.pathExists ./params.nix then import ./params.nix else import ./params.example.nix;

      hostNames = builtins.filter (
        name:
        let
          hostType = (builtins.readDir ./hosts).${name};
        in
        hostType == "directory" && !(nixpkgs.lib.hasPrefix "_" name)
      ) (builtins.attrNames (builtins.readDir ./hosts));

      hostContext = hostName:
        let
          hostPath = ./hosts + "/${hostName}";
          hostParamsPath = hostPath + "/params.nix";
          hostOverrides = if builtins.pathExists hostParamsPath then import hostParamsPath else { };
          # Root params provide shared defaults. A host can override only the
          # values that differ on that machine in hosts/<name>/params.nix.
          mergedParams = nixpkgs.lib.recursiveUpdate params hostOverrides;
          hostParams = mergedParams // {
            systemSettings = mergedParams.systemSettings // { inherit hostName; };
          };
          username = hostParams.userSettings.userName;
        in
        {
          inherit hostName hostPath hostParams username;
        };

      homeConfiguration = hostName:
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
            params = context.hostParams;
          };
          modules = [ ./home ];
        };

      hostConfiguration = hostName:
        let
          context = hostContext hostName;
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            inherit (context) username hostName hostParams;
            params = context.hostParams;
          };
          modules = [
            context.hostPath
          ];
        };
    in
    {
      # User-level configuration is deliberately separate from the system
      # output. Desktop/theme changes can use `nh home switch` without
      # rebuilding the kernel, hardware, and machine services.
      homeConfigurations = builtins.listToAttrs (
        map (hostName:
          let
            context = hostContext hostName;
          in
          {
            name = "${context.username}@${hostName}";
            value = homeConfiguration hostName;
          }) hostNames
      );
      nixosConfigurations = builtins.listToAttrs (
        map (hostName: {
          name = hostName;
          value = hostConfiguration hostName;
        }) hostNames
      );
    };
}
