# File manager with the upstream preview-tui plugin. Previews reuse the running
# Kitty instance through its remote-control socket, so this module installs its
# own opener script and passes Kitty's own socket setting through.

{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.file.".local/bin/nnn-opener" = {
    source = ./opener;
    executable = true;
  };

  home.sessionVariables = {
    NNN_OPENER = "nnn-opener";
    # preview-tui reads this as a mode selector rather than a command: only the
    # literal "icat" turns on Kitty graphics previews.
    NNN_PREVIEWIMGPROG = "icat";
    # NNN_TERMINAL is deliberately unset. With KITTY_LISTEN_ON below,
    # preview-tui picks tmux or kitty itself, so naming a terminal here could
    # only contradict that choice.
  } // lib.optionalAttrs config.programs.kitty.enable {
    # The same value Kitty itself is configured with, so the two cannot drift.
    KITTY_LISTEN_ON = config.programs.kitty.settings.listen_on or "";
  };

  programs.nnn = {
    enable = true;
    enableFishIntegration = true;
    plugins = {
      # The nnn package already ships the official plugins.
      src = "${pkgs.nnn}/share/plugins";
      mappings.p = "preview-tui";
    };
    # quitcd is off: its `n` function would clash with the `n` = nvim abbr.
    # Persistent sessions are off because nnn otherwise prompts for a session
    # path/name every time it starts.
    options = [
      # "H" # show hidden files by default
    ];
  };
}
