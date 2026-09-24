{ pkgs, ... }:

{
  # Make dconf/gsettings available so home-manager can apply the GTK theme
  # (home-manager writes the theme/icon to org/gnome/desktop/interface).
  programs.dconf.enable = true;

  # Dolphin is run under Sway rather than a full Plasma session.  Supply KDE's
  # applications menu so Dolphin can populate its "Open With" actions.
  environment.etc."xdg/menus/applications.menu".source =
    "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
}
