# foot terminal — themed from the shared palette.

{
  config,
  pkgs,
  lib,
  ...
}:

let
  v = import ./vars.nix { inherit config pkgs; };
  p = v.palette; # raw hex, no '#'
in
{
  xdg.configFile."foot/foot.ini".text = ''
    [main]
    font=monospace:size=11
    pad=8x8

    [cursor]
    style=beam

    # Matrix-green palette from theme.nix.
    [colors-dark]
    background=${p.base00}
    foreground=${p.base05}
    selection-foreground=${p.base06}
    selection-background=${p.base02}
    regular0=${p.base03}
    regular1=${p.base08}
    regular2=${p.base0B}
    regular3=${p.base0A}
    regular4=${p.base0D}
    regular5=${p.base0E}
    regular6=${p.base0C}
    regular7=${p.base05}
    bright0=${p.base04}
    bright1=${p.base08}
    bright2=${p.base0B}
    bright3=${p.base0A}
    bright4=${p.base0D}
    bright5=${p.base0E}
    bright6=${p.base0C}
    bright7=${p.base07}
  '';
}
