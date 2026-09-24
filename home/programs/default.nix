# General-purpose desktop / media apps and user programs that are not part of
# the Sway compositor setup itself.

{
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./nvim
    ./terminals
    ./browsers.nix
    ./dolphin.nix
    ./integrations.nix
    ./nnn.nix
    ./lf.nix
    ./tmux.nix
    ./gpg.nix
    ./ncdu.nix
  ];

  # Canonical list of standalone applications and support tools. Program
  # modules below provide configuration for packages that need it and manage
  # their own primary package through Home Manager.
  home.packages =
    with pkgs;
    [
      tldr
      signal-desktop
      keepassxc
      monero-gui
      kdePackages.kleopatra
      kdePackages.dolphin
      kdePackages.dolphin-plugins
      tor-browser
      discord
      imv
      mpv
      nautilus
      chafa
      librsvg
      fastfetch
      opencode
      codex
      nodejs
      uv
      steam
      ppsspp
      xdelta
      slack
      ffmpegthumbnailer
      less
      mediainfo
      ncdu
      poppler-utils
      tree
      unzip
    ]
    ++ [
      inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
}
