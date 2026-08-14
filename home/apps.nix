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

  # Optional local opencode config. Only installed when the file exists next
  # to the repo (it is machine-specific and intentionally not tracked), so a
  # fresh clone evaluates without it. Copy your own into place if you use it.
  xdg.configFile = lib.optionalAttrs (builtins.pathExists ../opencode.json) {
    "opencode/opencode.jsonc".source = ../opencode.json;
  };

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
