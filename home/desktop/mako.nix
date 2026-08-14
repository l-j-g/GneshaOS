# mako notifications — matrix-themed.

{
  config,
  pkgs,
  lib,
  ...
}:

let
  v = import ./vars.nix { inherit config pkgs; };
in
{
  services.mako = {
    enable = true;
    settings = {
      anchor = "top-right";
      default-timeout = 5000;
      background-color = v.bg;
      text-color = v.foreground;
      border-color = v.accent;
      border-size = 2;
      border-radius = 0;
      padding = "12";
      font = "monospace 11";
    };
    extraConfig = ''
      [urgency=critical]
      border-color=${v.critical}
      default-timeout=0
    '';
  };
}
