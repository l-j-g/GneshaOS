# Interactive shells and their integrations. Nix workflows live in home/cli.
{ pkgs, ... }:

{
  imports = [
    ./fish.nix
    ./zoxide.nix
    ./direnv.nix
    ./fzf.nix
  ];

  home.packages = [
    pkgs.lazydocker
    pkgs.zoxide
    pkgs.eza
    pkgs.bat
    pkgs.fd
    pkgs.ripgrep
    pkgs.fzf
    pkgs.fastfetch
    pkgs.htop
    pkgs.btop
    pkgs.jq
  ];
}
