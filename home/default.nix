{
  config,
  pkgs,
  lib,
  inputs,
  params,
  ...
}:

{
  imports = [
    ./shell.nix
    ./editors.nix
    ./neovim.nix
    ./apps.nix
    ./theme.nix
    ./desktop
    inputs.nix-index-database.homeModules.nix-index
    inputs.nix-colors.homeManagerModules.default
  ];

  home.username = params.userSettings.userName;
  home.homeDirectory = params.userSettings.homeDirectory;
  home.stateVersion = "25.05";

  # Seed a mutable user wallpaper directory once. Existing files are kept so
  # `cp xyz.jpg ~/wallpapers/wallpaper` remains the simple switching workflow.
  home.activation.installWallpaperArchive = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    wallpaperDir="${config.home.homeDirectory}/wallpapers"
    wallpaperFile="$wallpaperDir/wallpaper"
    legacyWallpaper="${config.home.homeDirectory}/wallpaper"

    # Migrate only the old Home Manager-managed symlinks, if present.
    if [ -L "$legacyWallpaper" ]; then
      legacyTarget="$(readlink "$legacyWallpaper")"
      case "$legacyTarget" in
        /nix/store/*|${config.home.homeDirectory}/wallpaper)
          $DRY_RUN_CMD rm "$legacyWallpaper"
          ;;
      esac
    fi

    canInstall=true
    if [ -L "$wallpaperDir" ]; then
      legacyTarget="$(readlink "$wallpaperDir")"
      case "$legacyTarget" in
        /nix/store/*)
          $DRY_RUN_CMD rm "$wallpaperDir"
          ;;
        *)
          echo "Skipping wallpaper archive migration: $wallpaperDir is a user symlink"
          canInstall=false
          ;;
      esac
    fi
    if [ -L "$wallpaperFile" ]; then
      legacyTarget="$(readlink "$wallpaperFile")"
      case "$legacyTarget" in
        /nix/store/*|${config.home.homeDirectory}/wallpapers/wallpaper)
          $DRY_RUN_CMD rm "$wallpaperFile"
          ;;
      esac
    fi

    if [ "$canInstall" = true ]; then
      $DRY_RUN_CMD mkdir -p "$wallpaperDir"

      # Keep archive names readable: Nix store paths have a hash-prefixed
      # basename, so copy each source to its explicit chronological filename.
      # Migrate only matching files that still have the exact source content.
      for preview in \
        "01-braille-mask-katakana.svg:03-braille-mask-katakana.svg:${../wallpapers/03-braille-mask-katakana.svg}" \
        "02-braille-direct.svg:02-braille-direct.svg:${../wallpapers/02-braille-direct.svg}" \
        "03-matrix-mosaic.svg:04-matrix-mosaic.svg:${../wallpapers/04-matrix-mosaic.svg}"; do
        legacyName="''${preview%%:*}"
        remainder="''${preview#*:}"
        previewName="''${remainder%%:*}"
        previewSource="''${remainder#*:}"
        for legacy in "$wallpaperDir"/*-"$legacyName"; do
          [ -f "$legacy" ] && [ ! -L "$legacy" ] || continue
          target="$wallpaperDir/$previewName"
          if cmp -s "$legacy" "$previewSource"; then
            if [ ! -e "$target" ] && [ ! -L "$target" ]; then
              $DRY_RUN_CMD mv "$legacy" "$target"
            elif [ -f "$target" ] && cmp -s "$target" "$previewSource"; then
              $DRY_RUN_CMD rm "$legacy"
            fi
          fi
        done
      done

      for preview in \
        "01-matrix-glow.svg:${../wallpapers/01-matrix-glow.svg}" \
        "02-braille-direct.svg:${../wallpapers/02-braille-direct.svg}" \
        "03-braille-mask-katakana.svg:${../wallpapers/03-braille-mask-katakana.svg}" \
        "04-matrix-mosaic.svg:${../wallpapers/04-matrix-mosaic.svg}" \
        "05-glpaper-matrix.glsl:${../wallpapers/05-glpaper-matrix.glsl}"; do
        previewName="''${preview%%:*}"
        previewSource="''${preview#*:}"
        if [ ! -e "$wallpaperDir/$previewName" ] && [ ! -L "$wallpaperDir/$previewName" ]; then
          $DRY_RUN_CMD cp "$previewSource" "$wallpaperDir/$previewName"
        fi
      done

      if [ ! -e "$wallpaperFile" ] && [ ! -L "$wallpaperFile" ]; then
        $DRY_RUN_CMD cp ${../wallpapers/03-braille-mask-katakana.svg} "$wallpaperFile"
      fi
    fi
  '';
}
