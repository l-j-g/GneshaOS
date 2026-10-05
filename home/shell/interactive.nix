{
  pkgs,
  lib,
  params,
  ...
}:

let
  arrDirectory = builtins.dirOf params.systemSettings.arrComposePath;
  airVpnProfile = pkgs.writeShellScriptBin "airvpn-profile" ''
    export GNESHA_ARR_DIRECTORY=${lib.escapeShellArg arrDirectory}
    export GNESHA_ARR_COMPOSE_FILE=${lib.escapeShellArg params.systemSettings.arrComposePath}
    exec ${pkgs.bash}/bin/bash ${./airvpn-profile} "$@"
  '';
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
    source = "${airVpnProfile}/bin/airvpn-profile";
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

  home.packages = [
    pkgs.lazydocker
    pkgs.zoxide
    pkgs.eza
    pkgs.bat
    pkgs.fd
    pkgs.ripgrep
    pkgs.fzf
    pkgs.fastfetch
    pkgs.htop
    pkgs.btop
    pkgs.jq
  ];

  programs.fish = {
    enable = true;
    preferAbbrs = true;
    shellAbbrs = {
      n = "nvim";
      v = "nvim";
      cfn = "cd $GNESHA_FLAKE_PATH/home/";
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
    };
    interactiveShellInit = builtins.readFile ./rg-fzf.fish + "\n" + themeFishInit;
  };

  programs.zoxide.enable = true;
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  programs.fzf.enable = true;
  programs.fzf.enableFishIntegration = true;
}
