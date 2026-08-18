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

      hostConfiguration = hostName:
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
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs username hostName;
            params = hostParams;
          };
          modules = [
            hostPath
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {
                inherit inputs;
                params = hostParams;
              };
              home-manager.users.${username} = import ./home;
            }
          ];
        };
    in
    {
      nixosConfigurations = builtins.listToAttrs (
        map (hostName: {
          name = hostName;
          value = hostConfiguration hostName;
        }) hostNames
      );
    };
}
