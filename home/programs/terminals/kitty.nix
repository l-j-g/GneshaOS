# Kitty terminal — themed from the shared palette.

{
  config,
  pkgs,
  lib,
  variables,
  ...
}:

let
  v = import ../../theme/palette.nix { inherit config pkgs; };
  p = v.palette; # raw hex, no '#'
in
{
  programs.kitty = {
    enable = true;
    font = {
      name = variables.terminalFontFamily;
      size = variables.terminalFontSize;
    };
    settings = {
      # Allow nnn's preview-tui plugin to create a Kitty split and use icat.
      allow_remote_control = "yes";
      # Keep the remote-control socket in this login session's private runtime dir.
      listen_on = "unix:$XDG_RUNTIME_DIR/kitty-{kitty_pid}";
      enabled_layouts = "splits";

      confirm_os_window_close = 0;
      cursor_shape = "beam";
      window_padding_width = 8;

      background = "#${p.base00}";
      foreground = "#${p.base05}";
      selection_foreground = "#${p.base06}";
      selection_background = "#${p.base02}";
    } // lib.listToAttrs (lib.imap0
      (index: color: lib.nameValuePair "color${toString index}" "#${color}")
      v.ansi);
  };
}
