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

  # Decode the Braille Ganesha into its individual dots, then replace each dot
  # with a tiny Matrix glyph. The fixed seed preserves Nix build reproducibility
  # while varying glyph shape, size, colour, and intensity.
  matrixGaneshaWallpaper = pkgs.runCommandLocal "matrix-ganesha-wallpaper.svg" {
    nativeBuildInputs = [ pkgs.perl ];
    sourceArt = ./ganesha-braille.txt;
  } ''
    perl -CSDA -Mutf8 - "$sourceArt" > "$out" <<'PERL'
    use strict;
    use warnings;

    my @code = split //, "0123456789ABCDEF[]{}?/\\\\+-=";
    my @dot_x = (0, 0, 0, 1, 1, 1, 0, 1);
    my @dot_y = (0, 1, 2, 0, 1, 2, 3, 3);
    # Match the original 20px monospace Braille layout: its cells are roughly
    # 12px wide by 20px tall.  The earlier 18x24 grid widened Ganesha by 50%.
    my ($cell_w, $cell_h) = (12, 20);
    my $start_x = (${wpW} - 60 * $cell_w) / 2 + $cell_w / 4;
    my $start_y = (${wpH} - 45 * $cell_h) / 2 + 7;
    srand(314159);
    my $matrix_art = "";
    my $line = 0;
    while (my $art_line = <>) {
      chomp $art_line;
      next if $art_line eq "";
      my @cells = split //, $art_line;
      for my $column (0 .. $#cells) {
        my $value = ord $cells[$column];
        next if $value < 0x2800 || $value > 0x28ff;
        my $bits = $value - 0x2800;
        for my $dot (0 .. 7) {
          next unless $bits & (1 << $dot);
          my $x = $start_x + $column * $cell_w + $dot_x[$dot] * ($cell_w / 2);
          my $y = $start_y + $line * $cell_h + $dot_y[$dot] * ($cell_h / 4);
          # Keep glyphs inside the 6x5px Braille-dot grid; larger characters
          # overlap their neighbours and visually warp the silhouette.
          my $size = 5 + int(rand() * 3);
          my $opacity = 0.42 + rand() * 0.52;
          my $glyph = $code[int(rand() * @code)];
          my $color = rand() < 0.07 ? "#f0fff2" : (rand() < 0.16 ? "#35ffcf" : "#00ff9c");
          $matrix_art .= sprintf qq{<text x="%.1f" y="%.1f" font-size="%d" fill="%s" fill-opacity="%.2f">%s</text>\n},
            $x, $y, $size, $color, $opacity, $glyph;
        }
      }
      $line++;
    }

    print <<'SVG';
    <svg xmlns="http://www.w3.org/2000/svg" width="${wpW}" height="${wpH}" viewBox="0 0 ${wpW} ${wpH}">
      <defs>
        <radialGradient id="glow" cx="50%" cy="40%" r="80%">
          <stop offset="0%" stop-color="#00ff9c" stop-opacity="0.10"/>
          <stop offset="70%" stop-color="#00ff41" stop-opacity="0.03"/>
          <stop offset="100%" stop-color="#050805" stop-opacity="0"/>
        </radialGradient>
        <pattern id="scanlines" width="2" height="4" patternUnits="userSpaceOnUse">
          <rect width="2" height="2" fill="#000000" fill-opacity="0.18"/>
        </pattern>
        <filter id="halo" x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur in="SourceGraphic" stdDeviation="6"/>
        </filter>
      </defs>
      <rect width="${wpW}" height="${wpH}" fill="#050805"/>
      <rect width="${wpW}" height="${wpH}" fill="url(#glow)"/>
      <g text-anchor="middle" dominant-baseline="central" font-family="Terminess Nerd Font, monospace" font-weight="bold" filter="url(#halo)" opacity="0.42">
    SVG
    print $matrix_art;
    print <<'SVG';
      </g>
      <g text-anchor="middle" dominant-baseline="central" font-family="Terminess Nerd Font, monospace" font-weight="bold">
    SVG
    print $matrix_art;
    print <<'SVG';
      </g>
      <rect width="${wpW}" height="${wpH}" fill="url(#scanlines)"/>
      <text x="${toString (params.userSettings.displayWidth / 2)}" y="${toString (params.userSettings.displayHeight - 110)}" text-anchor="middle" font-family="Terminess Nerd Font, Noto Sans Devanagari, sans-serif" font-size="42"
            fill="#00ff9c" fill-opacity="0.55" letter-spacing="1.5">ॐ गणपतये नमः</text>
    </svg>
    SVG
    PERL
  '';
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

  # Generated SVG wallpaper: every active Braille dot becomes a tiny, varied
  # Matrix glyph, preserving the original artwork's exact geometry.
  # Referenced from sway as `output * bg ~/.config/sway/generated_background.svg fill`.
  xdg.configFile."sway/generated_background.svg".source = matrixGaneshaWallpaper;
}
