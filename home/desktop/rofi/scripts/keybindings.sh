#!/usr/bin/env bash
# Display the generated Sway shortcut catalog with the shared Rofi theme.
set -euo pipefail
catalog=$1
shift

accent=$(awk 'match($0, /border-color:[[:space:]]*(#[0-9a-fA-F]{6})/, c) { print c[1]; exit }' \
  "${XDG_CONFIG_HOME:-$HOME/.config}/gnesha/rofi-live.rasi" 2>/dev/null || true)
[[ $accent =~ ^#[[:xdigit:]]{6}$ ]] || accent='#00ff9c'
jq -r --arg accent "$accent" '
  sort_by(.mode, .description, .key)[] |
  (.key | gsub("Mod4"; "Super") | gsub("Mod1"; "Alt")) as $key |
  "<b>\($key | @html)</b>  <span foreground=\"\($accent)\">[\(.mode | @html)]</span> — \(.description | @html)\u0000meta\u001f\(.command | gsub("[\\r\\n]"; " "))"
' "$catalog" | gnesha-rofi -dmenu -i -no-custom -markup-rows \
  -p Keybirdings -mesg 'Search shortcuts or actions • Super = Windows key • Escape closes' \
  -lines 12 -theme-str 'window { width: 85%; }' >/dev/null || [[ $? == 1 ]]
