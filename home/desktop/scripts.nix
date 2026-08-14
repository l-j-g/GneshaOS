# Vendored sway helper scripts (from the Manjaro sway scripts, adapted for
# Nix) and the nwg-wrapper help overlay assets. Scripts land in
# ~/.config/sway/scripts and are added to PATH.

{
  config,
  pkgs,
  lib,
  ...
}:

let
  # Scripts we install into sway's scripts dir. als-brightness.sh is used by
  # the systemd service directly (not by sway), so it is kept out.
  swayScripts = lib.filterAttrs (name: _: name != "als-brightness.sh") (builtins.readDir ./scripts);
  installScript = name: {
    source = ./scripts/${name};
    executable = true;
  };
in
{
  home.sessionPath = [ "$HOME/.config/sway/scripts" ];

  home.file = (builtins.listToAttrs (map (name: {
    name = ".config/sway/scripts/${name}";
    value = installScript name;
  }) (builtins.attrNames swayScripts))) // {
    ".config/nwg-wrapper/help.sh".source = ./nwg-wrapper/help.sh;
    ".config/nwg-wrapper/style.css".source = ./nwg-wrapper/style.css;
  };
}
