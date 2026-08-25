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

    # Migrate the old Home Manager-managed symlinks, if present.
    if [ -L "$legacyWallpaper" ]; then
      $DRY_RUN_CMD rm "$legacyWallpaper"
    fi
    if [ -L "$wallpaperDir" ]; then
      $DRY_RUN_CMD rm "$wallpaperDir"
    fi
    if [ -L "$wallpaperFile" ]; then
      $DRY_RUN_CMD rm "$wallpaperFile"
    fi

    $DRY_RUN_CMD mkdir -p "$wallpaperDir"
    for preview in \
      ${../wallpapers/01-braille-mask-katakana.svg} \
      ${../wallpapers/02-braille-direct.svg} \
      ${../wallpapers/03-matrix-mosaic.svg}; do
      if [ ! -e "$wallpaperDir/$(basename "$preview")" ]; then
        $DRY_RUN_CMD cp "$preview" "$wallpaperDir/"
      fi
    done

    if [ ! -e "$wallpaperFile" ]; then
      $DRY_RUN_CMD cp ${../wallpapers/01-braille-mask-katakana.svg} "$wallpaperFile"
    fi
  '';
}
