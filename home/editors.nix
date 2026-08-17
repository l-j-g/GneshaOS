{
  config,
  pkgs,
  lib,
  params,
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

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = params.userSettings.gitUserName;
        email = params.userSettings.gitUserEmail;
      };
      init.defaultBranch = "main";
      core.autocrlf = "input";
      push.autoSetupRemote = true;
    };
  };

  programs.gh.enable = true;
}
