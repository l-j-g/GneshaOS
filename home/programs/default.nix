# Program list: import configured programs; list standalone packages below.
# Group only natural families such as editors, shells and terminals.

{
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./coding-agents.nix
    ./editors
    ./shells
    ./git.nix
    ./terminals
    ./browsers.nix
    ./dolphin.nix
    ./integrations.nix
    ./nnn
    ./lf
    ./tmux.nix
    ./gpg.nix
    ./ncdu.nix
    ./yazi.nix
  ];

  # Canonical list of standalone applications and support tools. Program
  # modules below provide configuration for packages that need it and manage
  # their own primary package through Home Manager.
  home.packages = [
    pkgs.tldr
    pkgs.signal-desktop
    pkgs.keepassxc
    pkgs.monero-gui
    pkgs.kdePackages.kleopatra
    pkgs.tor-browser
    pkgs.discord
    pkgs.imv
    pkgs.mpv
    pkgs.nautilus
    pkgs.chafa
    pkgs.librsvg
    pkgs.fastfetch
    pkgs.nodejs
    pkgs.uv
    pkgs.steam
    pkgs.ppsspp
    pkgs.xdelta
    pkgs.slack
    pkgs.ffmpegthumbnailer
    pkgs.less
    pkgs.mediainfo
    pkgs.poppler-utils
    pkgs.tree
    pkgs.unzip
  ]
  ++ [
    inputs.mcp-nixos.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # User-installed wrappers live in ~/.local/bin, which comes before the
  # packaged programs so a module can shadow a packaged command.
  home.sessionPath = [ "$HOME/.local/bin" ];
}
