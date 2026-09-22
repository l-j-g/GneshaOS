# Dolphin's file-manager preferences and KDE colour integration.
#
# The colour scheme is generated from the same base16 palette used by the
# rest of the desktop, so changing variables.themeName updates Dolphin too.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  palette = config.colorScheme.palette;
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

  dolphinrc = ''
    [General]
    GlobalViewProps=true
    SortingChoice=0
    RenameInline=true
    ShowFullPath=true
    ShowFullPathInTitlebar=true
    OpenExternallyCalledFolderInNewTab=true
    AlwaysShowTabBar=true
    ShowCloseButtonOnTabs=true
    RememberOpenedTabs=true
    SplitView=false
    FilterBar=false
    ShowStatusBar=1
    ShowZoomSlider=true
    ShowToolTips=false
    LockPanels=true
    UseTabForSwitchingSplitView=true
    OpenNewTabAfterLastTab=true

    [IconsMode]
    UseSystemFont=true
    IconSize=48
    PreviewSize=96
    TextWidthIndex=1
    MaximumTextLines=2

    [CompactMode]
    UseSystemFont=true
    IconSize=32
    PreviewSize=64
    MaximumTextWidthIndex=1

    [DetailsMode]
    UseSystemFont=true
    IconSize=32
    PreviewSize=64
    LeftPadding=12
    RightPadding=12
    HighlightEntireRow=true
    ExpandableFolders=true

    [ContextMenu]
    ShowCopyMoveMenu=true
    ShowAddToPlaces=true
    ShowSortBy=true
    ShowViewMode=true
    ShowOpenInNewTab=true
    ShowOpenInNewWindow=true
    ShowOpenInSplitView=true
    ShowCopyLocation=true
    ShowDuplicateHere=true
    ShowOpenTerminal=true
    ShowCopyToOtherSplitView=true
    ShowMoveToOtherSplitView=true
  '';

  viewProperties = ''
    [Dolphin]
    Version=4
    ViewMode=1
    PreviewsShown=false
    GroupedSorting=false
    SortRole=text
    SortOrder=0
    SortFoldersFirst=true
    SortHiddenLast=false
    VisibleRoles=Details_size,Details_modificationtime,CustomizedDetails

    [Settings]
    HiddenFilesShown=false
  '';

  videoMimeTypes = [
    "application/x-matroska"
    "video/3gpp"
    "video/3gpp2"
    "video/avi"
    "video/divx"
    "video/dv"
    "video/flv"
    "video/mpeg"
    "video/mp2t"
    "video/mp4"
    "video/ogg"
    "video/quicktime"
    "video/vnd.divx"
    "video/webm"
    "video/x-anim"
    "video/x-avi"
    "video/x-flc"
    "video/x-fli"
    "video/x-flv"
    "video/x-m4v"
    "video/x-matroska"
    "video/x-mpeg"
    "video/x-mpeg2"
    "video/x-ms-asf"
    "video/x-ms-wmv"
    "video/x-msvideo"
    "video/x-ogm"
    "video/x-theora"
  ];
in
{
  # Dolphin now stores the global view as global/.directory. Remove the old
  # Home Manager-managed symlink first, otherwise activation cannot create the
  # directory at the same path.
  home.activation.migrateDolphinViewProperties = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    legacyGlobal="${config.home.homeDirectory}/.local/share/dolphin/view_properties/global"
    if [ -L "$legacyGlobal" ]; then
      legacyTarget="$(readlink "$legacyGlobal")"
      case "$legacyTarget" in
        /nix/store/*)
          $DRY_RUN_CMD rm "$legacyGlobal"
          ;;
      esac
    fi
  '';

  # Sway does not supply Plasma's Qt platform plugin automatically. It is
  # needed for Qt to consume kdeglobals and the selected color palette.
  qt = {
    enable = true;
    platformTheme.name = "kde";
    style.name = "breeze";
  };

  home.file.".local/share/color-schemes/GneshaBase16.colors".text = ''
    [General]
    Name=Gnesha Base16
    shadeSortColumn=true
  '' + colors;
  home.file.".local/share/dolphin/view_properties/global/.directory".text = viewProperties;
  xdg.configFile."dolphinrc".text = dolphinrc;
  xdg.configFile."kdeglobals".text = kdeglobals;

  # KDE caches application desktop files; rebuild it after Home Manager has
  # linked the new profile and MIME associations.
  home.activation.refreshKServiceCache = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    $DRY_RUN_CMD ${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
  '';

  # Keep a stable per-user desktop entry for Dolphin.  Entries created by
  # Dolphin's "Open With" dialog can contain `~` in Exec, which desktop-entry
  # launchers do not expand.
  xdg.desktopEntries.vlc = {
    name = "VLC media player";
    genericName = "Media player";
    comment = "Play multimedia files";
    exec = "${pkgs.vlc}/bin/vlc --started-from-file %U";
    icon = "vlc";
    terminal = false;
    categories = [
      "AudioVideo"
      "Player"
    ];
    mimeType = videoMimeTypes;
  };

  # Open video files launched from Dolphin with VLC.
  xdg.mimeApps = {
    enable = true;
    associations.added = lib.genAttrs videoMimeTypes (_: "vlc.desktop");
    defaultApplications = lib.genAttrs videoMimeTypes (_: "vlc.desktop");
  };
}
