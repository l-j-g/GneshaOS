# General-purpose desktop / media apps and user programs that are not part of
# the Sway compositor setup itself.

{
  config,
  pkgs,
  inputs,
  ...
}:

let
  # Keep the package list canonical while allowing configured program modules
  # to replace their raw package with the resulting configured package.
  appPkgs = pkgs // {
    nnn = config.programs.nnn.finalPackage;
  };
in
{
  imports = [
    ./integrations.nix
    ./nnn.nix
    ./lf.nix
    ./tmux.nix
    ./gpg.nix
  ];

  # Canonical list of standalone applications and support tools. Program
  # modules below provide configuration for packages that need it; their
  # primary package is managed by Home Manager.
  home.packages =
    with appPkgs;
    [
      tldr
      nnn
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
