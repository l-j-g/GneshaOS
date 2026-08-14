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

  # sway-extra.conf is static sway syntax, so user-adjustable values inside it
  # (gaps, screenshot upload URL) are filled in via placeholder substitution.
  extraConf = lib.replaceStrings
    [
      "__GAPS_INNER_PX__"
      "__GAPS_OUTER_PX__"
      "__SCREENSHOT_UPLOAD_URL__"
    ]
    [
      (toString u.gapsInner + "px")
      (toString u.gapsOuter + "px")
      u.screenshotUploadUrl
    ]
    (builtins.readFile ./sway-extra.conf);

  # Terminal (foot socket server -> footclient). Inlined (not $term var):
  # home-manager's sway module doesn't emit `set $term`/`set $menu` here.
  term = "footclient";
  termCwd = "${term} -D \"$(swaycwd 2>/dev/null || echo $HOME)\"";
  termFloat = "${term} --app-id floating_shell --window-size-chars 82x25";

  # Launcher (Manjaro: rofi combi = drun + run).
  menu = "rofi -show combi -combi-modes \"drun,run\" -terminal ${term} -show-icons -lines 10";

  # Clipboard picker (rofi + cliphist).
  clipboard = "cliphist list | rofi -dmenu -p \"Select item to copy\" -lines 10 | cliphist decode | wl-copy";

  # On-screen bar (wob) helpers.
  wob = "wob.sh \"${v.accent}\" \"${v.bg}\"";
  sinkVol = "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf \"%d\", $2*100}'";
  sourceVol = "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | awk '{printf \"%d\", $2*100}'";
  volumeUp = "${wob} $(wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ && ${sinkVol})";
  volumeDown = "${wob} $(wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && ${sinkVol})";
  volumeMute = "${wob} $(wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED && echo 0 || ${sinkVol})";
  micMute = "${wob} $(wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle && wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED && echo 0 || ${sourceVol})";
  brightnessUp = "${wob} $(brightness.sh up)";
  brightnessDown = "${wob} $(brightness.sh down)";

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
          text = v.subtle;
          indicator = v.subtleBg;
          childBorder = v.subtleBg;
        };
        unfocused = {
          border = v.selection;
          background = v.surface;
          text = v.subtle;
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
          text = v.subtle;
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
