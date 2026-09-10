# Sway compositor config — Manjaro-style bindings, themes, and startup.

{
  config,
  pkgs,
  lib,
  params,
  variables,
  ...
}:

let
  v = import ../../theme/palette.nix { inherit config pkgs; };
  mod = "Mod4";

  system = params.systemSettings;
  screenshotDir = lib.replaceStrings [ "~" ] [ config.home.homeDirectory ] variables.screenshotDir;

  # sway-extra.conf is static sway syntax, so user-adjustable values inside it
  # (gaps, screenshot upload URL) are filled in via placeholder substitution.
  extraConf = lib.replaceStrings
    [
      "__GAPS_INNER_PX__"
      "__GAPS_OUTER_PX__"
      "__STACKED_VIEW_FONT_SIZE__"
      "__SCREENSHOT_UPLOAD_URL__"
    ]
    [
      (toString variables.gapsInner + "px")
      (toString variables.gapsOuter + "px")
      (toString variables.stackedViewFontSize)
      variables.screenshotUploadUrl
    ]
    (builtins.readFile ./sway-extra.conf);

  # Terminal. Inlined (not $term var):
  # home-manager's sway module doesn't emit `set $term`/`set $menu` here.
  term = variables.terminal;
  # The default terminal shortcut attaches to one persistent tmux session.
  # Shift+Mod4+Return remains a plain Kitty terminal (see bindings.nix).
  termCwd = "${term} --directory \"$(swaycwd 2>/dev/null || echo $HOME)\" tmux new-session -A -s main";
  termFloat = "${term} --class floating_shell";

  # Launcher (Manjaro: rofi combi = drun + run).
  rofiLauncher = "${config.home.homeDirectory}/.config/sway/scripts/gnesha-rofi";
  menu = "${rofiLauncher} -show combi -combi-modes \"drun,run\" -terminal ${term} -show-icons -lines 10";

  # Clipboard picker (rofi + cliphist).
  clipboard = "cliphist list | ${rofiLauncher} -dmenu -p \"Select item to copy\" -lines 10 | cliphist decode | wl-copy";

  # Use an absolute path because Sway may be launched before Home Manager's
  # sessionPath is loaded into its environment.
  themePicker = "${config.home.homeDirectory}/.config/sway/scripts/theme-picker";

  # SwayOSD owns volume/brightness changes and displays the matching OSD.
  volumeUp = "swayosd-client --output-volume raise";
  volumeDown = "swayosd-client --output-volume lower";
  volumeMute = "swayosd-client --output-volume mute-toggle";
  micMute = "swayosd-client --input-volume mute-toggle";
  brightnessUp = "swayosd-client --brightness raise --device ${system.backlightDevice}";
  brightnessDown = "swayosd-client --brightness lower --device ${system.backlightDevice}";

  keybindings = import ./bindings.nix {
    inherit
      mod
      term
      termCwd
      termFloat
      menu
      clipboard
      volumeUp
      volumeDown
      volumeMute
      micMute
      brightnessUp
      brightnessDown
      themePicker
      ;
  };
in
{
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = true;
    extraConfig = {
      SCREENSHOTS = screenshotDir;
    };
  };

  wayland.windowManager.sway = {
    enable = true;
    package = pkgs.sway;
    systemd.enable = true;
    config = {
      modifier = mod;
      terminal = term;
      menu = menu;

      output = {
        # Native panel is ${toString system.displayWidth}x${toString system.displayHeight}
        # @ 14" -> ~216 dpi; scale comes from home/variables.nix.
        # (Wallpaper is applied via swaymsg in `startup` so sway config
        # validation doesn't fail before the SVG exists.)
        "*" = {
          scale = variables.displayScale;
        };
      };

      # Use Waybar below; do not also start Sway's default swaybar.
      bars = [ ];

      colors = {
        background = v.bg;
        focused = {
          border = v.accent;
          background = v.surface;
          text = v.foreground;
          indicator = v.accent;
          childBorder = v.surface;
        };
        focusedInactive = {
          border = v.subtleBg;
          background = v.surface;
          text = v.foreground;
          indicator = v.subtleBg;
          childBorder = v.subtleBg;
        };
        unfocused = {
          border = v.selection;
          background = v.surface;
          text = v.foreground;
          indicator = v.selection;
          childBorder = v.selection;
        };
        urgent = {
          border = v.critical;
          background = v.critical;
          text = v.bg;
          indicator = v.critical;
          childBorder = v.critical;
        };
        placeholder = {
          border = v.bg;
          background = v.bg;
          text = v.foreground;
          indicator = v.bg;
          childBorder = v.bg;
        };
      };

      input = {
        "type:touchpad" = {
          dwt = "enabled";
          tap = "enabled";
          natural_scroll = "enabled";
        };
        "type:keyboard" = {
          xkb_layout = system.keyboardLayout;
          xkb_options = system.keyboardOptions;
        };
      };

      startup = [
        { command = "mkdir -p ${variables.screenshotDir}"; }
        { command = "xdg-user-dirs-update"; }
        { command = "wlsunset -l ${toString system.latitude} -L ${toString system.longitude}"; }
        { command = "dex -a -e SWAY"; }
        { command = "noisetorch -u && noisetorch -i"; always = true; }
        {
          # User-selected wallpaper (replace ~/wallpapers/wallpaper to switch).
          command = "swaymsg \"output * bg ${config.home.homeDirectory}/wallpapers/wallpaper fill\"";
          always = true;
        }
      ];

      inherit keybindings;
    };
    extraConfig = extraConf;
  };

}
