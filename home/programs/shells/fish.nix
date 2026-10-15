# Fish shell, aliases and shared runtime theme integration.
{ ... }:

let
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
}
