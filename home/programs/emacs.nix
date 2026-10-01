# Emacs and the tools its configuration needs on the general PATH.

{
  config,
  pkgs,
  ...
}:

{
  # Doom's markdown preview and shell checker need these on the general PATH,
  # not only inside Neovim's wrapper.
  home.packages = with pkgs; [
    pandoc
    shellcheck
  ];

  # Nix owns the Emacs binary; Doom owns its checkout and package sync.
  programs.emacs = {
    enable = true;
    package = pkgs.emacs-pgtk;
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.config/emacs/bin"
  ];

  home.sessionVariables.DOOMDIR =
    "${config.home.homeDirectory}/.config/doom";
}
