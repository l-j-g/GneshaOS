{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    zoxide
    eza
    bat
    fd
    ripgrep
    fzf
    fastfetch
    htop
    btop
    jq
  ];

  programs.fish = {
    enable = true;
    preferAbbrs = true;
    shellAbbrs = {
      n = "nvim";
      v = "nvim";
    };
    shellAliases = {
      vim = "nvim";
      cf = "cd ~/.config";
      cfn = "cd ~/.config/nix/";
      ls = "eza --icons=auto";
      ll = "eza --icons=auto -la";
      cat = "bat";
      # NixOS build/apply
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#cf-fv1";
      retest = "sudo nixos-rebuild test --flake /etc/nixos#cf-fv1";       # activate, no boot entry
      rebuild-boot = "sudo nixos-rebuild boot --flake /etc/nixos#cf-fv1"; # build now, switch on reboot
      # Formatting
      nf = "nixfmt";
      nfcheck = "nixfmt --check";
      # Whole-flake validation
      nixcheck = "nix flake check --show-trace /etc/nixos";
      # Garbage collection
      nixgc = "sudo nix-collect-garbage -d";
    };
    functions = {
      # Eval-check a single flake option with a full error trace.
      # Usage: nixeval programs.neovim.plugins
      nixeval = {
        description = "Eval-check one flake option with full trace";
        body = "nix eval --show-trace \"path:/etc/nixos#nixosConfigurations.cf-fv1.config.$argv[1]\"";
      };
      # Syntax-check a .nix file fast (catches parse errors before eval).
      # Usage: nixparse hosts/cf-fv1/default.nix
      nixparse = {
        description = "Fast syntax check of a .nix file";
        body = "nix-instantiate --parse \"$argv[1]\" > /dev/null; and echo \"OK: $argv[1]\"";
      };
    };
  };

  programs.zoxide.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.fzf.enable = true;
}
