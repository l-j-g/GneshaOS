#!/bin/sh
# Output for nwg-wrapper -s help.sh (keybinding overlay).
cat <<'EOF'
<b>Keybindings</b>
Mod+Return        terminal (in cwd)
Mod+Shift+Return  terminal
Mod+d             launcher
Mod+Shift+d       launcher in new workspace
Mod+Shift+p       clipboard history
Mod+p             swayr window switcher
Alt+Tab           last used window
Mod+Tab           last used workspace
Mod+1..0          workspace 1..10
Mod+Shift+1..0    move window to workspace
Mod+n             new workspace
Mod+Shift+n       move to new workspace
Mod+Shift+m       move to new workspace & switch
Mod+f             fullscreen
Mod+Shift+f       fullscreen global
Mod+Shift+Space   floating toggle
Mod+Space         focus mode toggle
Mod+v / Mod+b     split vertical / horizontal
Mod+s / Mod+w     stacking / tabbed
Mod+e             toggle split
Mod+Shift+q       kill window
Mod+Shift+c       reload config
Mod+Shift+e       shutdown menu
Mod+Shift+r       record screen
Print             screenshot mode
Mod+r             resize mode
Mod+minus         scratchpad
Mod+Shift+minus   move to scratchpad
Mod+a             focus parent
Mod+Shift+i       inhibit idle
Mod+Shift+b       toggle waybar
Ctrl+Alt+Delete   task manager
Alt+Shift+e       emoji picker
Mod+?             this help
EOF
