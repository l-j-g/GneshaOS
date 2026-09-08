# General-purpose desktop / media apps that are not part of the Sway
# compositor setup itself.

{
  pkgs,
  inputs,
  ...
}:

{
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
    ]
    ++ [
      inputs.mcp-nixos.packages.${pkgs.system}.default
    ];
}
