# General-purpose desktop / media apps that are not part of the Sway
# compositor setup itself.

{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  home.packages =
    with pkgs;
    [
      firefox
      imv
      mpv
      fastfetch
      opencode
      codex
      uv
    ]
    ++ [
      inputs.mcp-nixos.packages.${pkgs.system}.default
    ];

  xdg.configFile."opencode/opencode.jsonc".source = ../opencode.json;

  # Open files from nnn with nvim (text) / imv/mpv (media).
  home.sessionVariables.NNN_OPENER = "nnn-opener";

  services.udiskie = {
    enable = true;
    settings = {
      automount = true;
      notify = true;
    };
  };

  programs.nnn = {
    enable = true;
    enableFishIntegration = true;
    # quitcd is off: its `n` function would clash with the `n` = nvim abbr.
    options = [
      "H" # show hidden files by default
      "S" # persistent sessions
    ];
  };
}
