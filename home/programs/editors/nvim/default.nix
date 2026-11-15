{
  inputs,
  pkgs,
  lib,
  ...
}:

let
  upstream = inputs.neovim-config;
  base = upstream.packages.${pkgs.stdenv.hostPlatform.system}.default;
  # Upstream's passthru shadows its module metadata, and extendConfiguration
  # imports ../../modules instead of ../modules. Recover the original module
  # inputs and invoke its builder directly, preserving its mainConfig and pkgs.
  baseConfig =
    (base.overrideAttrs (_: {
      passthru = { };
    })).meta.module.config;
  neovim = import "${upstream}/modules" {
    pkgs = baseConfig._module.args.pkgs;
    modules = baseConfig._module.specialArgs.currentModules ++ [ ./personal.nix ];
  };
in
{
  # Upstream already wraps Neovim with its configuration and plugins.
  home.packages = [ neovim ];
  home.sessionVariables = {
    EDITOR = lib.mkDefault "nvim";
    VISUAL = lib.mkDefault "nvim";
  };
}
