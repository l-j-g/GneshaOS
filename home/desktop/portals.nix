# Desktop portals for GTK applications and Sway screen sharing.
{ pkgs, ... }:

{
  xdg.portal = {
    enable = true;
    config.common.default = "gtk";
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-wlr
    ];
  };
}
