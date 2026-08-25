# Matrix-green desktop theme.
#
# One palette (nix-colors "colorscheme", base16 shape) drives every piece of
# the shell: waybar, foot, rofi, mako, swaylock, sway colors, and wallpaper.
# The active wallpaper is selected through the top-level `wallpaper` symlink.

{
  config,
  pkgs,
  lib,
  params,
  ...
}:

{
  # base16 palette — phosphor green on near-black.
  # Note: nix-colors strips the leading '#', so downstream code that needs
  # CSS-style colors re-adds it (see desktop/vars.nix).
  colorScheme = {
    slug = "matrix-green";
    name = "Matrix Green";
    author = params.userSettings.userName;

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
      base09 = "#ffa53d"; # orange / warning
      base0A = "#ccff3d"; # yellow
      base0B = "#00ff9c"; # green / accent
      base0C = "#35ffcf"; # cyan
      base0D = "#53aaff"; # blue
      base0E = "#c14dff"; # magenta
      base0F = "#2e7a4a"; # dim green
    };
  };

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
    # GTK4 apps are rare here (foot/rofi/firefox are GTK3); adopt home-manager's
    # new default of not applying a separate GTK4 theme.
    gtk4.theme = lib.mkDefault null;
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };
}
