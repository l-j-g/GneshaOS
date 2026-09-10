# General-purpose desktop / media apps and user programs that are not part of
# the Sway compositor setup itself.

{
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./integrations.nix
    ./nnn.nix
    ./lf.nix
    ./tmux.nix
    ./gpg.nix
  ];

  # Canonical list of standalone applications and support tools. Program
  # modules below provide configuration for packages that need it and manage
  # their own primary package through Home Manager.
  home.packages =
    with pkgs;
    [
      tldr
      librewolf-bin
      tor-browser
      discord
      firefox
      imv
      mpv
      nautilus
      chafa
      librsvg
      fastfetch
      opencode
      codex
      uv
      steam
      ppsspp
      xdelta
      slack
      ffmpegthumbnailer
      less
      mediainfo
      poppler-utils
      tree
      unzip
    ]
    ++ [
      inputs.mcp-nixos.packages.${pkgs.system}.default
    ];
}
