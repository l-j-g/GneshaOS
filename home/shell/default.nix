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
  homeProfile = "${params.userSettings.userName}@${hostName}";
  flakeRef = "${flakePath}#${hostName}";
  systemBuildRef = "${flakePath}#nixosConfigurations.${hostName}.config.system.build.toplevel";
  fishWorkflow = lib.replaceStrings
    [ "__FLAKE_PATH__" "__HOST_NAME__" "__HOME_PROFILE__" "__SYSTEM_BUILD_REF__" ]
    [ flakePath hostName homeProfile systemBuildRef ]
    (builtins.readFile ./nix-workflow.fish);
  themeFishInit = ''
    # Runtime theme previews update these files without rewriting shell config.
    set -l gneshaThemeDir "$HOME/.config/gnesha"
    if test -r "$gneshaThemeDir/eza-colors"
      set -gx EZA_COLORS (string collect < "$gneshaThemeDir/eza-colors")
      set -gx LS_COLORS "$EZA_COLORS"
    end
    if test -r "$gneshaThemeDir/lf-colors"
      set -gx LF_COLORS (string collect < "$gneshaThemeDir/lf-colors")
    end
  '';
in
{
  home.sessionVariables.BAT_THEME = "ansi";

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
    nix-inspect
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
      cfn = "cd ~/.config/nix/home/";
      cf = "cd ~/.config";
    };
    shellAliases = {
      vim = "nvim";
      nnnp = "nnn -a -P p";
      lf = "lf-image";
      ls = "eza --icons=auto";
      ll = "eza --icons=auto -la";
      cat = "BAT_THEME=ansi bat";
      nixrun = ",";
      nf = "nixfmt";
      nfcheck = "nixfmt --check";
      nixcheck = "nix flake check --show-trace ${flakePath}";
      nixgc = "sudo nix-collect-garbage -d";
      home-rebuild-raw = "nh home switch ${flakePath} -c ${homeProfile}";
      # Explicit raw fallbacks for feature parity or troubleshooting.
      rebuild-raw = "sudo nixos-rebuild switch --flake ${flakeRef}";
      retest-raw = "sudo nixos-rebuild test --flake ${flakeRef}";
      rebuild-boot-raw = "sudo nixos-rebuild boot --flake ${flakeRef}";
    };
    interactiveShellInit = fishWorkflow + "\n" + themeFishInit;
  };

  programs.zoxide.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.fzf.enable = true;
}
