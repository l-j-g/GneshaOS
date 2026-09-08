# Matrix-green desktop theme.
#
# One palette (nix-colors "colorscheme", base16 shape) drives every piece of
# the shell: waybar, Kitty, rofi, mako, swaylock, sway colors, and wallpaper.
# The active wallpaper is selected through the top-level `wallpaper` symlink.

{
  config,
  pkgs,
  lib,
  params,
  inputs,
  ...
}:

let
  customThemes = {
    "matrix-green" = {
      slug = "matrix-green";
      name = "Matrix Green";
      palette = {
        base00 = "#050805"; # default background
        base01 = "#0b100c"; # lighter background / waybar bar
        base02 = "#121a13"; # selection background
        base03 = "#1c2b1f"; # comments / subtle
        base04 = "#2b412f"; # dark foreground
        base05 = "#a8f5c9"; # default foreground (soft phosphor)
        base06 = "#d3ffdf"; # light foreground
        base07 = "#f0fff2"; # lightest foreground
        base08 = "#ff2e57"; # red / critical
        base09 = "#ffa53d"; # orange
        base0A = "#d19a66"; # muted copper / warning
        base0B = "#00ff9c"; # green / accent
        base0C = "#35ffcf"; # cyan
        base0D = "#53aaff"; # blue
        base0E = "#c14dff"; # magenta
        base0F = "#2e7a4a"; # dim green
      };
    };
  };

  themes = customThemes // inputs.nix-colors.colorSchemes;
  themeName = params.userSettings.themeName;
  availableThemes = lib.sort builtins.lessThan (builtins.attrNames themes);
  selectedTheme =
    if builtins.hasAttr themeName themes then
      themes.${themeName}
    else
      throw ''
        Unknown themeName '${themeName}'. Available themes: ${lib.concatStringsSep ", " availableThemes}
      '';
in
{
  # Base16 palette selected from the custom theme plus nix-colors schemes.
  # Note: nix-colors strips the leading '#' from config.colorScheme.palette;
  # desktop/vars.nix re-adds it for CSS/Sway/rofi-style consumers.
  colorScheme = selectedTheme // {
    author = params.userSettings.userName;
  };

  # The picker reads this declarative catalog and writes only themeName in
  # params.nix; the selected scheme still requires the normal rebuild flow.
  home.file.".config/gnesha/theme-names".text =
    lib.concatStringsSep "\n" availableThemes + "\n";

  # Pairing dark GTK theme + dark Papirus icons so GTK apps match the shell.
  # Colloid-Green-Dark: modern dark GTK theme with a green accent.
  gtk = {
    enable = true;
    theme = {
      name = "Colloid-Green-Dark";
      package = pkgs.colloid-gtk-theme.override {
        themeVariants = [ "green" ];
        colorVariants = [ "dark" ];
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    # GTK4 apps are rare here (rofi/firefox are GTK3); adopt home-manager's
    # new default of not applying a separate GTK4 theme.
    gtk4.theme = lib.mkDefault null;
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };
}
