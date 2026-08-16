# Sway keybindings, mirroring Manjaro Sway's modes/default with the agreed
# deviations (btop via task manager, stacking kept on Mod+s, etc.).
#
# Invoked from sway.nix with the shared variables.
{
  mod,
  termCwd,
  term,
  termFloat,
  menu,
  clipboard,
  volumeUp,
  volumeDown,
  volumeMute,
  micMute,
  brightnessUp,
  brightnessDown,
}:
let
  m = mod;
in
{
  # Launch // Terminal
  "${m}+Return" = "exec ${termCwd}";
  "${m}+Shift+Return" = "exec ${term}";

  # Action // Kill focused window
  "${m}+Shift+q" = "kill";

  # Launch // Launcher
  "${m}+d" = "exec ${menu}";
  "Mod1+space" = "exec ${menu}";

  # Launch // Clipboard picker
  "${m}+Shift+p" = "exec ${clipboard}";

  # Action // Reload
  "${m}+Shift+c" = "reload";

  # Action // Toggle waybar
  "${m}+Shift+b" = "exec pkill -USR1 -x waybar";

  # Media keys (work while locked)
  "--locked XF86AudioRaiseVolume" = "exec ${volumeUp}";
  "--locked XF86AudioLowerVolume" = "exec ${volumeDown}";
  "--locked XF86AudioMute" = "exec ${volumeMute}";
  "XF86AudioMicMute" = "exec ${micMute}";
  "--locked XF86MonBrightnessUp" = "exec ${brightnessUp}";
  "--locked XF86MonBrightnessDown" = "exec ${brightnessDown}";
  "--locked XF86AudioPlay" = "exec playerctl play-pause";
  "XF86AudioNext" = "exec playerctl next";
  "XF86AudioPrev" = "exec playerctl previous";

  "XF86Search" = "exec ${menu}";
  "XF86PowerOff" = "mode shutdown";
  "XF86TouchpadToggle" = "input type:touchpad events toggle enabled disabled";

  # Navigation // focus
  "${m}+Left" = "focus left";
  "${m}+Down" = "focus down";
  "${m}+Up" = "focus up";
  "${m}+Right" = "focus right";
  "${m}+h" = "focus left";
  "${m}+j" = "focus down";
  "${m}+k" = "focus up";
  "${m}+l" = "focus right";

  # Navigation // move window
  "${m}+Shift+Left" = "move left";
  "${m}+Shift+Down" = "move down";
  "${m}+Shift+Up" = "move up";
  "${m}+Shift+Right" = "move right";
  "${m}+Shift+h" = "move left";
  "${m}+Shift+j" = "move down";
  "${m}+Shift+k" = "move up";
  "${m}+Shift+l" = "move right";

  # Navigation // move workspace to output
  "${m}+Mod1+Right" = "move workspace to output right";
  "${m}+Mod1+Left" = "move workspace to output left";
  "${m}+Mod1+Down" = "move workspace to output down";
  "${m}+Mod1+Up" = "move workspace to output up";

  # Navigation // swayr window switching
  "${m}+p" = "exec swayr switch-window";
  "Mod1+Tab" = "exec swayr switch-to-urgent-or-lru-window";
  "${m}+Tab" = "workspace back_and_forth";

  # Workspaces 1-10
  "${m}+1" = "workspace number 1";
  "${m}+2" = "workspace number 2";
  "${m}+3" = "workspace number 3";
  "${m}+4" = "workspace number 4";
  "${m}+5" = "workspace number 5";
  "${m}+6" = "workspace number 6";
  "${m}+7" = "workspace number 7";
  "${m}+8" = "workspace number 8";
  "${m}+9" = "workspace number 9";
  "${m}+0" = "workspace number 10";

  # Move focused window to workspace (and follow it)
  "${m}+Shift+1" = "move container to workspace number 1, workspace number 1";
  "${m}+Shift+2" = "move container to workspace number 2, workspace number 2";
  "${m}+Shift+3" = "move container to workspace number 3, workspace number 3";
  "${m}+Shift+4" = "move container to workspace number 4, workspace number 4";
  "${m}+Shift+5" = "move container to workspace number 5, workspace number 5";
  "${m}+Shift+6" = "move container to workspace number 6, workspace number 6";
  "${m}+Shift+7" = "move container to workspace number 7, workspace number 7";
  "${m}+Shift+8" = "move container to workspace number 8, workspace number 8";
  "${m}+Shift+9" = "move container to workspace number 9, workspace number 9";
  "${m}+Shift+0" = "move container to workspace number 10, workspace number 10";

  # Launch // Launcher in a new empty workspace
  "${m}+Shift+d" = "exec first-empty-workspace --switch, exec ${menu}";

  # Navigation // first empty workspace
  "${m}+n" = "exec first-empty-workspace --switch";
  "${m}+Shift+n" = "exec first-empty-workspace --move";
  "${m}+Shift+m" = "exec first-empty-workspace --move --switch";

  # Layout
  "${m}+b" = "splith";
  "${m}+v" = "splitv";
  "${m}+s" = "layout stacking";
  "${m}+w" = "layout tabbed";
  "${m}+e" = "layout toggle split";

  # Fullscreen
  "${m}+f" = "fullscreen";
  "${m}+Shift+f" = "fullscreen global";

  # Scaling
  "Mod1+plus" = "exec scale.sh up";
  "Mod1+minus" = "exec scale.sh down";
  "${m}+equal" = "exec scale.sh default";

  # Floating / focus
  "${m}+Shift+Space" = "floating toggle";
  "${m}+Space" = "focus mode_toggle";
  "${m}+a" = "focus parent";

  # Launch // Help overlay (nwg-wrapper)
  "${m}+question" = "exec sway-help --toggle";

  # Launch // Inhibit idle
  "${m}+Shift+i" = "exec inhibit-idle toggle";

  # Task manager
  "Ctrl+Mod1+Delete" = "exec once ${termFloat} btop";

  # Launch // Emoji picker
  "Mod1+Shift+e" = "exec emoji-picker";

  # Screenshot / recording / shutdown / scratchpad / resize modes
  "Print" = "mode \"screenshot (o/p)\"";
  "${m}+Shift+r" = "mode recording";
  "${m}+Escape" = "exec killall -SIGINT wf-recorder";
  "${m}+Shift+e" = "mode shutdown";
  "${m}+minus" = "scratchpad show";
  "${m}+Shift+minus" = "move scratchpad";
  "${m}+r" = "mode resize";

  # Allow killing floating shell windows with Esc
  "--release Escape" = "[app_id=\"floating_shell\" con_id=__focused__] kill";
}
