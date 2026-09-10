# Kitty terminal — themed from the shared palette.

{
  config,
  pkgs,
  params,
  ...
}:

let
  v = import ../../desktop/vars.nix { inherit config pkgs; };
  p = v.palette; # raw hex, no '#'
in
{
  programs.kitty = {
    enable = true;
    font = {
      name = "monospace";
      size = params.userSettings.terminalFontSize;
    };
    settings = {
      # Allow nnn's preview-tui plugin to create a Kitty split and use icat.
      allow_remote_control = "yes";
      listen_on = "unix:/tmp/kitty";
      enabled_layouts = "splits";

      confirm_os_window_close = 0;
      cursor_shape = "beam";
      window_padding_width = 8;

      background = "#${p.base00}";
      foreground = "#${p.base05}";
      selection_foreground = "#${p.base06}";
      selection_background = "#${p.base02}";
      color0 = "#${p.base03}";
      color1 = "#${p.base08}";
      color2 = "#${p.base0B}";
      color3 = "#${p.base0A}";
      color4 = "#${p.base0D}";
      color5 = "#${p.base0E}";
      color6 = "#${p.base0C}";
      color7 = "#${p.base05}";
      color8 = "#${p.base04}";
      color9 = "#${p.base08}";
      color10 = "#${p.base0B}";
      color11 = "#${p.base0A}";
      color12 = "#${p.base0D}";
      color13 = "#${p.base0E}";
      color14 = "#${p.base0C}";
      color15 = "#${p.base07}";
    };
  };
}
