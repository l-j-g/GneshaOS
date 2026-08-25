# Matrix-green desktop theme.
#
# One palette (nix-colors "colorscheme", base16 shape) drives every piece of
# the shell: waybar, foot, rofi, mako, swaylock, sway colors, generated
# wallpaper. GTK apps get a dark theme + Papirus icons that pair with it.

{
  config,
  pkgs,
  lib,
  params,
  ...
}:

let
  # Wallpaper SVG is sized to the native panel resolution (top-level params).
  wpW = toString params.userSettings.displayWidth;
  wpH = toString params.userSettings.displayHeight;

  # Use the original Braille Ganesha as an SVG mask. The Matrix rain is clipped
  # inside it, preserving the figure's proportions while keeping the code look.
  ganeshaArt = lib.filter (line: line != "") (lib.splitString "\n" (builtins.readFile ./ganesha-braille.txt));
  artFontPx = 20;
  artLineH = 20;
  artStartY = builtins.div (params.userSettings.displayHeight - (builtins.length ganeshaArt) * artLineH) 2;
  artCenterX = params.userSettings.displayWidth / 2;

  renderGanesha = builtins.concatStringsSep "\n" (lib.imap0 (i: line:
    ''<text x="${toString artCenterX}" y="${toString (artStartY + i * artLineH)}" text-anchor="middle" xml:space="preserve" font-family="Terminess Nerd Font, monospace" font-size="${toString artFontPx}">${line}</text>''
  ) ganeshaArt);
in
{
  # base16 palette — phosphor green on near-black.
  # Note: nix-colors strips the leading '#', so downstream code that needs
  # CSS-style colors re-adds it (see desktop/vars.nix).
  colorScheme = {
    slug = "matrix-green";
    name = "Matrix Green";
    author = params.userSettings.userName;

    palette = {
      base00 = "#050805"; # default background
      base01 = "#0b100c"; # lighter background / waybar bar
      base02 = "#121a13"; # selection background
      base03 = "#1c2b1f"; # comments / subtle
      base04 = "#2b412f"; # dark foreground
      base05 = "#a8f5c9"; # default foreground (soft phosphor)
      base06 = "#d3ffdf"; # light foreground
      base07 = "#f0fff2"; # lightest foreground
      base08 = "#ff2e57"; # red / critical
      base09 = "#ffa53d"; # orange / warning
      base0A = "#ccff3d"; # yellow
      base0B = "#00ff9c"; # green / accent
      base0C = "#35ffcf"; # cyan
      base0D = "#53aaff"; # blue
      base0E = "#c14dff"; # magenta
      base0F = "#2e7a4a"; # dim green
    };
  };

  # Pairing dark GTK theme + dark Papirus icons so GTK apps match the shell.
  # Colloid-Green-Dark: modern dark GTK theme with a green accent.
  gtk = {
    enable = true;
    theme = {
      name = "Colloid-Green-Dark";
      package = pkgs.colloid-gtk-theme.override {
        themeVariants = [ "green" ];
        colorVariants = [ "dark" ];
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    # GTK4 apps are rare here (foot/rofi/firefox are GTK3); adopt home-manager's
    # new default of not applying a separate GTK4 theme.
    gtk4.theme = lib.mkDefault null;
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  # Generated SVG wallpaper: the original Braille Ganesha masks the Matrix
  # rain, with a visible green outline and dark corners.
  # Referenced from sway as `output * bg ~/.config/sway/generated_background.svg fill`.
  xdg.configFile."sway/generated_background.svg".text = ''
    <svg xmlns="http://www.w3.org/2000/svg" width="${wpW}" height="${wpH}" viewBox="0 0 ${wpW} ${wpH}">
      <defs>
        <radialGradient id="glow" cx="50%" cy="40%" r="80%">
          <stop offset="0%" stop-color="#00ff9c" stop-opacity="0.10"/>
          <stop offset="70%" stop-color="#00ff41" stop-opacity="0.03"/>
          <stop offset="100%" stop-color="#050805" stop-opacity="0"/>
        </radialGradient>
        <pattern id="rain" width="48" height="200" patternUnits="userSpaceOnUse">
          <g font-family="Terminess Nerd Font, monospace" font-size="18" font-weight="bold">
            <text x="4"  y="26" fill="#00ff9c" fill-opacity="0.95">ア</text>
            <text x="4"  y="44" fill="#00ff41" fill-opacity="0.60">7</text>
            <text x="4"  y="62" fill="#00ff9c" fill-opacity="0.40">ウ</text>
            <text x="4"  y="80" fill="#35ffcf" fill-opacity="0.25">1</text>
            <text x="4"  y="98" fill="#00ff41" fill-opacity="0.14">エ</text>
            <text x="24" y="66" fill="#00ff41" fill-opacity="0.85">キ</text>
            <text x="24" y="84" fill="#00ff9c" fill-opacity="0.55">3</text>
            <text x="24" y="102" fill="#00ff41" fill-opacity="0.35">ク</text>
            <text x="24" y="120" fill="#00ff9c" fill-opacity="0.18">0</text>
            <text x="24" y="138" fill="#35ffcf" fill-opacity="0.10">ケ</text>
            <text x="42" y="10" fill="#00ff9c" fill-opacity="0.80">サ</text>
            <text x="42" y="28" fill="#00ff41" fill-opacity="0.50">5</text>
            <text x="42" y="46" fill="#35ffcf" fill-opacity="0.30">シ</text>
            <text x="42" y="64" fill="#00ff41" fill-opacity="0.16">2</text>
            <text x="42" y="82" fill="#00ff9c" fill-opacity="0.08">ス</text>
          </g>
        </pattern>
        <pattern id="scanlines" width="2" height="4" patternUnits="userSpaceOnUse">
          <rect width="2" height="2" fill="#000000" fill-opacity="0.18"/>
        </pattern>
        <filter id="halo" x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur in="SourceGraphic" stdDeviation="6"/>
        </filter>
        <mask id="ganesha">
          <g fill="#ffffff" stroke="#ffffff" stroke-width="8" stroke-linejoin="round" stroke-linecap="round">
            ${renderGanesha}
          </g>
        </mask>
      </defs>
      <rect width="${wpW}" height="${wpH}" fill="#050805"/>
      <rect width="${wpW}" height="${wpH}" fill="url(#glow)"/>
      <g fill="#00ff9c" fill-opacity="0.18" stroke="#00ff9c" stroke-opacity="0.55" stroke-width="3" filter="url(#halo)">
        ${renderGanesha}
      </g>
      <g fill="#00ff9c" fill-opacity="0.10" stroke="#00ff9c" stroke-opacity="0.45" stroke-width="1.5">
        ${renderGanesha}
      </g>
      <rect width="${wpW}" height="${wpH}" fill="url(#rain)" mask="url(#ganesha)"/>
      <rect width="${wpW}" height="${wpH}" fill="url(#scanlines)"/>
      <text x="${toString artCenterX}" y="${toString (params.userSettings.displayHeight - 110)}" text-anchor="middle" font-family="Noto Sans Devanagari, sans-serif" font-size="42"
            fill="#00ff9c" fill-opacity="0.55" letter-spacing="1.5">ॐ गणपतये नमः</text>
    </svg>
  '';
}
