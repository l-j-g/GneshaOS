# Render the Dolphin/KDE color files from the shared Base16 palette.
{ lib, palette }:

let
  rgb = color:
    lib.concatStringsSep "," (
      map
        (offset: toString (lib.fromHexString (builtins.substring offset 2 color)))
        [ 0 2 4 ]
    );

  bg = rgb palette.base00;
  surface = rgb palette.base01;
  selection = rgb palette.base02;
  dim = rgb palette.base04;
  foreground = rgb palette.base05;
  light = rgb palette.base06;
  lightest = rgb palette.base07;
  red = rgb palette.base08;
  yellow = rgb palette.base0A;
  green = rgb palette.base0B;
  cyan = rgb palette.base0C;
  blue = rgb palette.base0D;

  colors = ''
    [Colors:Button]
    BackgroundAlternate=${surface}
    BackgroundNormal=${surface}
    DecorationFocus=${green}
    DecorationHover=${cyan}
    ForegroundActive=${green}
    ForegroundInactive=${dim}
    ForegroundNegative=${red}
    ForegroundNeutral=${yellow}
    ForegroundNormal=${foreground}
    ForegroundPositive=${green}
    ForegroundVisited=${blue}

    [Colors:Complementary]
    BackgroundAlternate=${surface}
    BackgroundNormal=${bg}
    DecorationFocus=${green}
    DecorationHover=${cyan}
    ForegroundActive=${green}
    ForegroundInactive=${dim}
    ForegroundNegative=${red}
    ForegroundNeutral=${yellow}
    ForegroundNormal=${light}
    ForegroundPositive=${green}
    ForegroundVisited=${blue}

    [Colors:Selection]
    BackgroundAlternate=${surface}
    BackgroundNormal=${selection}
    DecorationFocus=${green}
    DecorationHover=${cyan}
    ForegroundActive=${lightest}
    ForegroundInactive=${dim}
    ForegroundNegative=${red}
    ForegroundNeutral=${yellow}
    ForegroundNormal=${lightest}
    ForegroundPositive=${green}
    ForegroundVisited=${blue}

    [Colors:Tooltip]
    BackgroundAlternate=${surface}
    BackgroundNormal=${surface}
    DecorationFocus=${green}
    DecorationHover=${cyan}
    ForegroundActive=${green}
    ForegroundInactive=${dim}
    ForegroundNegative=${red}
    ForegroundNeutral=${yellow}
    ForegroundNormal=${foreground}
    ForegroundPositive=${green}
    ForegroundVisited=${blue}

    [Colors:View]
    BackgroundAlternate=${surface}
    BackgroundNormal=${bg}
    DecorationFocus=${green}
    DecorationHover=${cyan}
    ForegroundActive=${green}
    ForegroundInactive=${dim}
    ForegroundNegative=${red}
    ForegroundNeutral=${yellow}
    ForegroundNormal=${foreground}
    ForegroundPositive=${green}
    ForegroundVisited=${blue}

    [Colors:Window]
    BackgroundAlternate=${bg}
    BackgroundNormal=${surface}
    DecorationFocus=${green}
    DecorationHover=${cyan}
    ForegroundActive=${green}
    ForegroundInactive=${dim}
    ForegroundNegative=${red}
    ForegroundNeutral=${yellow}
    ForegroundNormal=${foreground}
    ForegroundPositive=${green}
    ForegroundVisited=${blue}
  '';

  kdeglobals = ''
    [General]
    ColorScheme=GneshaBase16
    Name=Gnesha Base16
    font=Noto Sans,11,-1,5,50,0,0,0,0,0
    menuFont=Noto Sans,11,-1,5,50,0,0,0,0,0
    smallestReadableFont=Noto Sans,10,-1,5,50,0,0,0,0,0
    toolBarFont=Noto Sans,11,-1,5,50,0,0,0,0,0
    windowTitleFont=Noto Sans,11,-1,5,50,0,0,0,0,0

    [Icons]
    Theme=Papirus-Dark

    [KDE]
    contrast=4
    widgetStyle=breeze
  '' + colors;
in
{
  inherit colors kdeglobals;
  colorScheme = ''
    [General]
    Name=Gnesha Base16
    shadeSortColumn=true
  '' + colors;
}
