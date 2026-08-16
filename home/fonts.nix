# Font setup:
#  - Terminess (TTF port of Terminus, nerd-patched) for the desktop/terminal
#    stack. The bitmap Terminus smears when scaled by GUI apps (neovide#2372);
#    the TTF renders sharp.
#  - Original Terminus bitmap font (terminus_font) for the Linux virtual
#    console, sized up for the 216dpi panel.
#  - fontconfig rules are expressed as localConf XML (this NixOS version has no
#    structured-attrset form for fontconfig; XML is the declarative way here).

{ config, pkgs, lib, ... }:

let
  # Nixpkgs currently ships Terminess Nerd Font from Terminus 4.49.2.
  # Pin the patched 4.49.3 Nerd Fonts release; fixes blurry outlines.
  terminessNerdFont = pkgs.stdenvNoCC.mkDerivation {
    pname = "terminess-nerd-font";
    version = "4.49.3";
    src = pkgs.fetchurl {
      url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.0/Terminus.zip";
      hash = "sha256-CSdNsL2iJdcca+hQIi7hD+z5bHeSEZHbT2kNZkuz7w4=";
    };
    nativeBuildInputs = [ pkgs.unzip ];
    dontConfigure = true;
    unpackPhase = ''
      runHook preUnpack
      unzip "$src"
      runHook postUnpack
    '';
    installPhase = ''
      install -d "$out/share/fonts/truetype/Terminess"
      for font in ./*.ttf; do
        install -m 0644 "$font" "$out/share/fonts/truetype/Terminess/"
      done
      install -Dm644 LICENSE.txt "$out/share/licenses/$pname/LICENSE.txt"
    '';
  };
in
{
  fonts.packages = [
    terminessNerdFont
    pkgs.terminus_font
    pkgs.noto-fonts
    pkgs.noto-fonts-cjk-sans
    pkgs.noto-fonts-color-emoji
    pkgs.liberation_ttf
    pkgs.symbola
    pkgs.nerd-fonts.symbols-only
    pkgs.nerd-fonts.fira-code
    pkgs.fira-code-symbols
    pkgs.mplus-outline-fonts.githubRelease
    pkgs.dina-font
    pkgs.proggyfonts
  ];

  fonts.fontconfig = {
    # Terminess TTF (non-mono) is the desktop monospace. It renders sharp at
    # any size; no bitmap-style hinting rules needed.
    defaultFonts.monospace = [ "Terminess Nerd Font" ];
  };

  console = {
    # 16x32 double-size Terminus: 135x45 on the 2160x1440 panel.
    # (Kernel default would be 8x16 VGA at this resolution.)
    font = "${pkgs.terminus_font}/share/consolefonts/ter-v32n.psf.gz";
    earlySetup = true;
    packages = [ pkgs.terminus_font ];
  };
}
