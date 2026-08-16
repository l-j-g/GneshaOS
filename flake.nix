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

      # Single source of truth for every user-changeable value (username,
      # hostname, resolution, scaling, paths, ...). Edit params.nix — see
      # params.example.nix for the fully documented template. Falls back to
      # the example so a fresh clone evaluates even before you've written
      # your own params.nix.
      params = if builtins.pathExists ./params.nix then import ./params.nix else import ./params.example.nix;

      # Kept as a specialArg for modules that predate params (hardening.nix,
      # btrfs.nix); derived from the same source so they can never diverge.
      username = params.userSettings.userName;
    in
    {
      nixosConfigurations.${params.systemSettings.hostName} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs username params; };
        modules = [
          # Host dir name is repo layout, independent of the hostName param.
          ./hosts/cf-fv1
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs params; };
            home-manager.users.${username} = import ./home;
          }
        ];
      };
    };
}
