# Sway compositor config — Manjaro-style bindings, themes, and startup.

{
  config,
  pkgs,
  lib,
  params,
  ...
}:

let
  v = import ./vars.nix { inherit config pkgs; };
  mod = "Mod4";

  u = params.userSettings;

  # sway-extra.conf is static sway syntax, so user-adjustable gap values are
  # filled in via placeholder substitution.
  extraConf = lib.replaceStrings
    [
      "__GAPS_INNER_PX__"
      "__GAPS_OUTER_PX__"
    ]
    [
      (toString u.gapsInner + "px")
      (toString u.gapsOuter + "px")
    ]
    (builtins.readFile ./sway-extra.conf);

  # Terminal (foot socket server -> footclient). Inlined (not $term var):
  # home-manager's sway module doesn't emit `set $term`/`set $menu` here.
  term = "footclient";
  # The default terminal shortcut attaches to one persistent tmux session.
  # Shift+Mod4+Return remains a plain Foot terminal (see bindings.nix).
  termCwd = "${term} -D \"$(swaycwd 2>/dev/null || echo $HOME)\" tmux new-session -A -s main";
  termFloat = "${term} --app-id floating_shell --window-size-chars 82x25";

  # Launcher (Manjaro: rofi combi = drun + run).
  menu = "rofi -show combi -combi-modes \"drun,run\" -terminal ${term} -show-icons -lines 10";

  # Clipboard picker (rofi + cliphist).
  clipboard = "cliphist list | rofi -dmenu -p \"Select item to copy\" -lines 10 | cliphist decode | wl-copy";

  # SwayOSD owns volume/brightness changes and displays the matching OSD.
  volumeUp = "swayosd-client --output-volume raise";
  volumeDown = "swayosd-client --output-volume lower";
  volumeMute = "swayosd-client --output-volume mute-toggle";
  micMute = "swayosd-client --input-volume mute-toggle";
  brightnessUp = "swayosd-client --brightness raise --device ${u.backlightDevice}";
  brightnessDown = "swayosd-client --brightness lower --device ${u.backlightDevice}";

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
      ;
  };
in
{
  wayland.windowManager.sway = {
    enable = true;
    package = pkgs.sway;
    systemd.enable = true;
    config = {
      modifier = mod;
      terminal = term;
      menu = menu;

      output = {
        # Native panel is ${toString u.displayWidth}x${toString u.displayHeight}
        # @ 14" -> ~216 dpi; scale comes from the top-level params.
        # (Wallpaper is applied via swaymsg in `startup` so sway config
        # validation doesn't fail before the SVG exists.)
        "*" = {
          scale = u.displayScale;
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
          xkb_layout = u.keyboardLayout;
          xkb_options = u.keyboardOptions;
        };
      };

      startup = [
        { command = "mkdir -p ${u.screenshotDir}"; }
        { command = "xdg-user-dirs-update"; }
        { command = "waybar"; }
        { command = "nm-applet --indicator"; }
        { command = "blueman-applet"; }
        { command = "wlsunset -l ${toString u.latitude} -L ${toString u.longitude}"; }
        { command = "dex -a -e SWAY"; }
        { command = "noisetorch -u && noisetorch -i"; always = true; }
        {
          # Matrix wallpaper (applied on every reload, Manjaro-style).
          command = "swaymsg \"output * bg ${config.home.homeDirectory}/.config/sway/generated_background.svg fill\"";
          always = true;
        }
      ];

      inherit keybindings;
    };
    extraConfig = extraConf;
  };

}
