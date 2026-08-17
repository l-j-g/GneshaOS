{
  config,
  pkgs,
  lib,
  params,
  ...
}:

let
  # Rebuild targets — host + flake location come from the top-level params.
  flakePath = params.systemSettings.flakePath;
  hostName = params.systemSettings.hostName;
  flakeRef = "${flakePath}#${hostName}";
  systemBuildRef = "${flakePath}#nixosConfigurations.${hostName}.config.system.build.toplevel";
  fishWorkflow = lib.replaceStrings
    [ "__FLAKE_PATH__" "__HOST_NAME__" "__SYSTEM_BUILD_REF__" ]
    [ flakePath hostName systemBuildRef ]
    (builtins.readFile ./scripts/nix-workflow.fish);
in
{
  home.packages = with pkgs; [
    zoxide
    eza
    bat
    fd
    ripgrep
    fzf
    fastfetch
    htop
    btop
    jq
    nh
    nvd
    nix-output-monitor
  ];

  # Use the prebuilt nixpkgs index so `, command` and `nix-locate` work
  # immediately without a local index-generation step.
  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;

  programs.fish = {
    enable = true;
    preferAbbrs = true;
    shellAbbrs = {
      n = "nvim";
      v = "nvim";
    };
    shellAliases = {
      vim = "nvim";
      nnnp = "nnn -a -P p";
      lf = "lf-image";
      cf = "cd ~/.config";
      cfn = "cd ~/.config/nix/";
      ls = "eza --icons=auto";
      ll = "eza --icons=auto -la";
      cat = "bat";
      nixrun = ",";
      nf = "nixfmt";
      nfcheck = "nixfmt --check";
      nixcheck = "nix flake check --show-trace ${flakePath}";
      nixgc = "sudo nix-collect-garbage -d";
      # Explicit raw fallbacks for feature parity or troubleshooting.
      rebuild-raw = "sudo nixos-rebuild switch --flake ${flakeRef}";
      retest-raw = "sudo nixos-rebuild test --flake ${flakeRef}";
      rebuild-boot-raw = "sudo nixos-rebuild boot --flake ${flakeRef}";
    };
    interactiveShellInit = fishWorkflow;
  };

  programs.zoxide.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.fzf.enable = true;
}
