# Shared Base16 desktop theme.
#
# One palette (nix-colors "colorscheme", base16 shape) drives every piece of
# the desktop: GTK, Dolphin, terminals, waybar, rofi, mako, and Sway.
# The active wallpaper is selected through the top-level `wallpaper` symlink.

{
  config,
  pkgs,
  lib,
  params,
  variables,
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
  themeName = variables.themeName;
  availableThemes = lib.sort builtins.lessThan (builtins.attrNames themes);
  paletteFields = [
    "base00"
    "base01"
    "base02"
    "base03"
    "base04"
    "base05"
    "base06"
    "base07"
    "base08"
    "base09"
    "base0A"
    "base0B"
    "base0C"
    "base0D"
    "base0E"
    "base0F"
  ];
  stripHash = color: builtins.replaceStrings [ "#" ] [ "" ] color;
  themeData = lib.concatMapStringsSep "\n" (name:
    let
      palette = themes.${name}.palette;
    in
    lib.concatStringsSep "\t" ([ name ] ++ map (field: stripHash palette.${field}) paletteFields)
  ) availableThemes + "\n";
  selectedTheme =
    if builtins.hasAttr themeName themes then
      themes.${themeName}
    else
      throw ''
        Unknown themeName '${themeName}'. Available themes: ${lib.concatStringsSep ", " availableThemes}
      '';
  palette = config.colorScheme.palette;
  brightness = color:
    let
      channel = offset: lib.fromHexString (builtins.substring offset 2 color);
    in
    299 * channel 0 + 587 * channel 2 + 114 * channel 4;
  dark = brightness palette.base00 < brightness palette.base05;
  # adw-gtk3 and libadwaita share these semantic colors. Generate both the
  # GTK named colors and modern GTK4 CSS variables from the selected Base16.
  gtkColors = {
    accent_color = palette.base0D;
    accent_bg_color = palette.base0D;
    accent_fg_color = palette.base00;
    destructive_color = palette.base08;
    destructive_bg_color = palette.base08;
    destructive_fg_color = palette.base00;
    success_color = palette.base0B;
    success_bg_color = palette.base0B;
    success_fg_color = palette.base00;
    warning_color = palette.base0A;
    warning_bg_color = palette.base0A;
    warning_fg_color = palette.base00;
    error_color = palette.base08;
    error_bg_color = palette.base08;
    error_fg_color = palette.base00;
    window_bg_color = palette.base00;
    window_fg_color = palette.base05;
    view_bg_color = palette.base00;
    view_fg_color = palette.base05;
    headerbar_bg_color = palette.base01;
    headerbar_fg_color = palette.base05;
    headerbar_backdrop_color = palette.base01;
    sidebar_bg_color = palette.base01;
    sidebar_fg_color = palette.base05;
    sidebar_backdrop_color = palette.base01;
    secondary_sidebar_bg_color = palette.base02;
    secondary_sidebar_fg_color = palette.base05;
    secondary_sidebar_backdrop_color = palette.base02;
    card_bg_color = palette.base01;
    card_fg_color = palette.base05;
    dialog_bg_color = palette.base01;
    dialog_fg_color = palette.base05;
    popover_bg_color = palette.base01;
    popover_fg_color = palette.base05;
  };
  gtkNamedColors = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: color: "@define-color ${name} #${color};") gtkColors
  );
  gtkCssVariables = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: color:
      "  --${lib.replaceStrings [ "_" ] [ "-" ] name}: #${color};"
    ) gtkColors
  );
in
{
  # Base16 palette selected from the custom theme plus nix-colors schemes.
  # Note: nix-colors strips the leading '#' from config.colorScheme.palette;
  # theme/palette.nix re-adds it for CSS/Sway/rofi-style consumers.
  colorScheme = selectedTheme // {
    author = params.userSettings.userName;
  };

  # The picker reads these declarative catalogs. It can preview a palette at
  # runtime, but only writes themeName to home/variables.nix when the user
  # accepts it.
  home.file.".config/gnesha/theme-names".text =
    lib.concatStringsSep "\n" availableThemes + "\n";
  home.file.".config/gnesha/theme-data".text = themeData;

  # Use a recolorable base instead of a fixed green theme.
  gtk = {
    enable = true;
    colorScheme = if dark then "dark" else "light";
    theme = {
      name = if dark then "adw-gtk3-dark" else "adw-gtk3";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    gtk3.extraCss = gtkNamedColors;
    # Preserve libadwaita's widget styling, including Nautilus, and override
    # its semantic colors rather than importing a GTK3 stylesheet.
    gtk4 = {
      theme = null;
      extraCss = gtkNamedColors + "\n:root {\n${gtkCssVariables}\n}\n";
    };
  };

  imports = [ ./wallpapers.nix ];
}
