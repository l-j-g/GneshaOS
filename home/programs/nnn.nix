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
    options = [
      "H" # show hidden files by default
      "S" # persistent sessions
    ];
  };
}
