{
  config,
  pkgs,
  lib,
  params,
  variables,
  ...
}:

let
  # Rebuild targets — host + flake location come from the top-level params.
  flakePath = params.systemSettings.flakePath;
  hostName = params.systemSettings.hostName;
  homeProfile = "${params.userSettings.userName}@${hostName}";
  flakeRef = "${flakePath}#${hostName}";
  systemBuildRef = "${flakePath}#nixosConfigurations.${hostName}.config.system.build.toplevel";
  rebuild = pkgs.writeShellApplication {
    name = "gnesha-rebuild";
    runtimeInputs = [ pkgs.nix pkgs.nh pkgs.jq pkgs.coreutils ];
    text = ''
      # Stale login environments must not make recovery depend on Docker.
      unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
      buildDir=$(mktemp -d -t gnesha-rebuild.XXXXXX)
      trap 'rm -rf -- "$buildDir"' EXIT
      # Freeze the input once: neither edits nor the background updater can
      # change what gets activated between these two builds.
      snapshot=$(nix flake metadata --json --no-write-lock-file ${lib.escapeShellArg flakePath} | jq -er .path)
      nix build --out-link "$buildDir/system" --no-write-lock-file \
        "$snapshot#nixosConfigurations.${hostName}.config.system.build.toplevel"
      nix build --out-link "$buildDir/home" --no-write-lock-file \
        "$snapshot#homeConfigurations.\"${homeProfile}\".activationPackage"
      # nh receives the exact built closures, not a newly evaluated flake.
      nh os switch "$buildDir/system"
      nh home switch "$buildDir/home" -b backup
    '';
  };
  showPublicKey = pkgs.writeShellApplication {
    name = "pubkey";
    runtimeInputs = [ pkgs.coreutils pkgs.wl-clipboard pkgs.xclip ];
    text = ''
      keyFile=${lib.escapeShellArg variables.publicKeyFile}
      if [[ ! -r "$keyFile" ]]; then
        echo "pubkey: cannot read $keyFile" >&2
        exit 1
      fi

      cat -- "$keyFile"
      if [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
        wl-copy < "$keyFile"
        echo "Public key copied to clipboard." >&2
      elif [[ -n "''${DISPLAY:-}" ]]; then
        xclip -selection clipboard < "$keyFile"
        echo "Public key copied to clipboard." >&2
      else
        echo "No graphical clipboard is available; printed only." >&2
      fi
    '';
  };
  decryptClipboard = pkgs.writeShellApplication {
    name = "declypt";
    runtimeInputs = [ pkgs.gnupg pkgs.wl-clipboard pkgs.xclip ];
    text = ''
      if [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
        wl-paste --no-newline | gpg --decrypt
      elif [[ -n "''${DISPLAY:-}" ]]; then
        xclip -o -selection clipboard | gpg --decrypt
      else
        echo "declypt: no graphical clipboard is available" >&2
        exit 1
      fi
    '';
  };
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

  home.file.".local/bin/airvpn-profile" = {
    source = ./airvpn-profile;
    executable = true;
  };

  xdg.configFile."airvpn/proxy.compose.yaml" = lib.mkIf
    (params.systemSettings.dockerProxy.enable or false) {
      # JSON is valid YAML and keeps the published port in sync with the client.
      text = builtins.toJSON {
        services.gluetun = {
          environment.HTTPPROXY = "on";
          ports = [ "127.0.0.1:${toString params.systemSettings.dockerProxy.port}:8888/tcp" ];
        };
      };
    };

  home.packages = with pkgs; [
    rebuild
    showPublicKey
    decryptClipboard
    lazydocker
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
      avpn = "airvpn-profile";
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
      home-rebuild-raw = "nh home switch ${flakePath} -c ${homeProfile} -b backup";
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
