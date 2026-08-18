{
  # Make dconf/gsettings available so home-manager can apply the GTK theme
  # (home-manager writes the theme/icon to org/gnome/desktop/interface).
  programs.dconf.enable = true;
}
