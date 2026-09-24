{
  pkgs,
  ...
}:

{
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
