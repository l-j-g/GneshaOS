# Sway keybindings, mirroring Manjaro Sway's modes/default with the agreed
# deviations (btop via task manager, stacking kept on Mod+s, etc.).
#
# Edit the key on the left and the category, description, and command below.
# sway.nix assigns this structure to gnesha.keybindings, then projects each
# binding.command into Sway. Rofi uses the same metadata for its reference.
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
  themePicker,
  scaleScript,
  settings,
}:
let
  m = mod;
  bind = category: description: command: { inherit category description command; };
in
{
  # Launch // Terminal
  "${m}+Return" = bind "Launch" "Open terminal" "exec ${term}";
  "${m}+Shift+Return" = bind "Launch" "Open terminal in current directory" "exec ${termCwd}";

  # Action // Kill focused window
  "${m}+Shift+q" = bind "Action" "Kill focused window" "kill";

  # Launch // Launcher
  "${m}+d" = bind "Launch" "Launcher" "exec ${menu}";
  "Mod1+space" = bind "Launch" "Launcher" "exec ${menu}";

  # Launch // Clipboard picker
  "${m}+Shift+p" = bind "Launch" "Clipboard picker" "exec ${clipboard}";

  # Launch // Gnesha settings editor
  "${m}+Shift+s" = bind "Launch" "Gnesha settings editor" "exec ${settings}";

  # Launch // Base16 theme picker (runtime preview + background Home Manager activation)
  "${m}+Shift+t" = bind "Appearance" "Preview and apply theme" "exec ${themePicker}";

  # Action // Reload
  "${m}+Shift+c" = bind "Action" "Reload" "reload";

  # Action // Toggle waybar
  "${m}+Shift+b" = bind "Action" "Toggle waybar" "exec pkill -USR1 -x waybar";

  # Media keys (work while locked)
  "--locked XF86AudioRaiseVolume" = bind "Media" "Raise volume" "exec ${volumeUp}";
  "--locked XF86AudioLowerVolume" = bind "Media" "Lower volume" "exec ${volumeDown}";
  "--locked XF86AudioMute" = bind "Media" "Toggle audio mute" "exec ${volumeMute}";
  "XF86AudioMicMute" = bind "Media" "Toggle microphone mute" "exec ${micMute}";
  "--locked XF86MonBrightnessUp" = bind "Display" "Raise brightness" "exec ${brightnessUp}";
  "--locked XF86MonBrightnessDown" = bind "Display" "Lower brightness" "exec ${brightnessDown}";
  "--locked XF86AudioPlay" = bind "Media" "Play or pause" "exec playerctl play-pause";
  "XF86AudioNext" = bind "Media" "Next track" "exec playerctl next";
  "XF86AudioPrev" = bind "Media" "Previous track" "exec playerctl previous";

  "XF86Search" = bind "Launch" "Open launcher" "exec ${menu}";
  "XF86PowerOff" = bind "Modes" "Enter shutdown mode" "mode shutdown";
  "XF86TouchpadToggle" =
    bind "Input" "Toggle touchpad"
      "input type:touchpad events toggle enabled disabled";

  # Navigation // focus
  "${m}+Left" = bind "Navigation" "Focus left" "focus left";
  "${m}+Down" = bind "Navigation" "Focus down" "focus down";
  "${m}+Up" = bind "Navigation" "Focus up" "focus up";
  "${m}+Right" = bind "Navigation" "Focus right" "focus right";
  "${m}+h" = bind "Navigation" "Focus left" "focus left";
  "${m}+j" = bind "Navigation" "Focus down" "focus down";
  "${m}+k" = bind "Navigation" "Focus up" "focus up";
  "${m}+l" = bind "Navigation" "Focus right" "focus right";

  # Navigation // move window
  "${m}+Shift+Left" = bind "Navigation" "Move left" "move left";
  "${m}+Shift+Down" = bind "Navigation" "Move down" "move down";
  "${m}+Shift+Up" = bind "Navigation" "Move up" "move up";
  "${m}+Shift+Right" = bind "Navigation" "Move right" "move right";
  "${m}+Shift+h" = bind "Navigation" "Move left" "move left";
  "${m}+Shift+j" = bind "Navigation" "Move down" "move down";
  "${m}+Shift+k" = bind "Navigation" "Move up" "move up";
  "${m}+Shift+l" = bind "Navigation" "Move right" "move right";

  # Navigation // move workspace to output
  "${m}+Mod1+Right" =
    bind "Navigation" "Move workspace to output right"
      "move workspace to output right";
  "${m}+Mod1+Left" =
    bind "Navigation" "Move workspace to output left"
      "move workspace to output left";
  "${m}+Mod1+Down" =
    bind "Navigation" "Move workspace to output down"
      "move workspace to output down";
  "${m}+Mod1+Up" = bind "Navigation" "Move workspace to output up" "move workspace to output up";

  # Navigation // swayr window switching
  "${m}+p" = bind "Navigation" "swayr window switching" "exec swayr switch-window";
  "Mod1+Tab" = bind "Navigation" "swayr window switching" "exec swayr switch-to-urgent-or-lru-window";
  "${m}+Tab" = bind "Navigation" "Return to previous workspace" "workspace back_and_forth";

  # Workspaces 1-10
  "${m}+1" = bind "Workspaces" "Switch to workspace 1" "workspace number 1";
  "${m}+2" = bind "Workspaces" "Switch to workspace 2" "workspace number 2";
  "${m}+3" = bind "Workspaces" "Switch to workspace 3" "workspace number 3";
  "${m}+4" = bind "Workspaces" "Switch to workspace 4" "workspace number 4";
  "${m}+5" = bind "Workspaces" "Switch to workspace 5" "workspace number 5";
  "${m}+6" = bind "Workspaces" "Switch to workspace 6" "workspace number 6";
  "${m}+7" = bind "Workspaces" "Switch to workspace 7" "workspace number 7";
  "${m}+8" = bind "Workspaces" "Switch to workspace 8" "workspace number 8";
  "${m}+9" = bind "Workspaces" "Switch to workspace 9" "workspace number 9";
  "${m}+0" = bind "Workspaces" "Switch to workspace 10" "workspace number 10";

  # Move focused window to workspace (and follow it)
  "${m}+Shift+1" =
    bind "Workspaces" "Move window to workspace 1 and follow"
      "move container to workspace number 1, workspace number 1";
  "${m}+Shift+2" =
    bind "Workspaces" "Move window to workspace 2 and follow"
      "move container to workspace number 2, workspace number 2";
  "${m}+Shift+3" =
    bind "Workspaces" "Move window to workspace 3 and follow"
      "move container to workspace number 3, workspace number 3";
  "${m}+Shift+4" =
    bind "Workspaces" "Move window to workspace 4 and follow"
      "move container to workspace number 4, workspace number 4";
  "${m}+Shift+5" =
    bind "Workspaces" "Move window to workspace 5 and follow"
      "move container to workspace number 5, workspace number 5";
  "${m}+Shift+6" =
    bind "Workspaces" "Move window to workspace 6 and follow"
      "move container to workspace number 6, workspace number 6";
  "${m}+Shift+7" =
    bind "Workspaces" "Move window to workspace 7 and follow"
      "move container to workspace number 7, workspace number 7";
  "${m}+Shift+8" =
    bind "Workspaces" "Move window to workspace 8 and follow"
      "move container to workspace number 8, workspace number 8";
  "${m}+Shift+9" =
    bind "Workspaces" "Move window to workspace 9 and follow"
      "move container to workspace number 9, workspace number 9";
  "${m}+Shift+0" =
    bind "Workspaces" "Move window to workspace 10 and follow"
      "move container to workspace number 10, workspace number 10";

  # Launch // Launcher in a new empty workspace
  "${m}+Shift+d" =
    bind "Launch" "Launcher in a new empty workspace"
      "exec first-empty-workspace --switch, exec ${menu}";

  # Navigation // first empty workspace
  "${m}+n" = bind "Navigation" "first empty workspace" "exec first-empty-workspace --switch";
  "${m}+Shift+n" = bind "Navigation" "first empty workspace" "exec first-empty-workspace --move";
  "${m}+Shift+m" =
    bind "Navigation" "first empty workspace"
      "exec first-empty-workspace --move --switch";

  # Layout
  "Mod1+j" = bind "Layout" "Split horizontally" "splith";
  "Mod1+k" = bind "Layout" "Split vertically" "splitv";
  # Isolate the focused window so siblings stay beside its new stack or tabs.
  "${m}+s" = bind "Layout" "Stack focused window" "split v; layout stacking";
  "${m}+w" = bind "Layout" "Tab focused window" "split v; layout tabbed";
  "${m}+e" = bind "Action" "Layout toggle split" "layout toggle split";

  # Fullscreen
  "${m}+f" = bind "Action" "Fullscreen" "fullscreen";
  "${m}+Shift+f" = bind "Action" "Fullscreen global" "fullscreen global";

  # Scaling
  "Mod1+plus" = bind "Action" "Scaling" "exec ${scaleScript} up";
  "Mod1+minus" = bind "Action" "Scaling" "exec ${scaleScript} down";
  "${m}+equal" = bind "Action" "Scaling" "exec ${scaleScript} default";

  # Ghostty handles the font-size change natively; release bindings only
  # display the resulting size without stealing the key from the terminal.
  "--release Ctrl+equal" =
    bind "Terminal" "Show terminal font size"
      "exec ghostty-font-size-notify up";
  "--release Ctrl+plus" =
    bind "Terminal" "Show terminal font size"
      "exec ghostty-font-size-notify up";
  "--release Ctrl+minus" =
    bind "Terminal" "Show terminal font size"
      "exec ghostty-font-size-notify down";
  "--release Ctrl+0" =
    bind "Terminal" "Show terminal font size"
      "exec ghostty-font-size-notify reset";

  # Floating / focus
  "${m}+Shift+Space" = bind "Action" "Floating toggle" "floating toggle";
  "${m}+Space" = bind "Action" "Focus mode_toggle" "focus mode_toggle";
  "${m}+a" = bind "Action" "Focus parent" "focus parent";

  # Launch // Search keyboard shortcuts (Shift+/ types ?)
  "${m}+Shift+slash" = bind "Launch" "Search keyboard shortcuts" "exec gnesha-keybindings";

  # Launch // Inhibit idle
  "${m}+Shift+i" = bind "Launch" "Inhibit idle" "exec inhibit-idle toggle";

  # Task manager
  "Ctrl+Mod1+Delete" = bind "Action" "Task manager" "exec once ${termFloat} btop";

  # Launch // Emoji picker
  "Mod1+Shift+e" = bind "Launch" "Emoji picker" "exec emoji-picker";

  # Screenshot / recording / shutdown / scratchpad / resize modes
  "Print" = bind "Modes" "Enter screenshot (o/p) mode" "mode \"screenshot (o/p)\"";
  "${m}+Shift+r" = bind "Modes" "Enter recording mode" "mode recording";
  "${m}+Escape" = bind "Recording" "Stop recording" "exec recorder.sh --stop";
  "${m}+Shift+e" = bind "Modes" "Enter shutdown mode" "mode shutdown";
  "${m}+minus" = bind "Action" "Scratchpad show" "scratchpad show";
  "${m}+Shift+minus" = bind "Action" "Move scratchpad" "move scratchpad";
  "${m}+r" = bind "Modes" "Enter resize mode" "mode resize";

  # Allow killing floating shell windows with Esc
  "--release Escape" =
    bind "Action" "Close focused floating shell"
      "[app_id=\"floating_shell\" con_id=__focused__] kill";
}
