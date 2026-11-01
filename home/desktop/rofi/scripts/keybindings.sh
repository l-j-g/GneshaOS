#!/usr/bin/env bash
# Search the effective Sway bindings; editing belongs in the Nix definitions.
set -euo pipefail
config=$1

accent=$(awk 'match($0, /border-color:[[:space:]]*(#[0-9a-fA-F]{6})/, c) { print c[1]; exit }' \
  "${XDG_CONFIG_HOME:-$HOME/.config}/gnesha/rofi-live.rasi" 2>/dev/null || true)
[[ $accent =~ ^#[[:xdigit:]]{6}$ ]] || accent='#00ff9c'

jq -r --arg accent "$accent" '
  .catalog | sort_by(.category, .mode, .description, .key) | .[] |
  (.key | sub("^(--[^ ]+ +)+"; "")) as $chord |
  "<span foreground=\"\($accent)\">[\(.category | @html)]</span> " +
  "<b>\($chord | gsub("Mod4"; "Super") | gsub("Mod1"; "Alt") | @html)</b> :: " +
  (.description | @html) +
  (if .key | contains("--release ") then " (on release)" else "" end) +
  (if .key | contains("--locked ") then " (also when locked)" else "" end) +
  (if .key | contains("--no-repeat ") then " (no repeat)" else "" end) +
  "\u0000meta\u001f\(.command | gsub("[\r\n]"; " "))"
' "$config" | gnesha-rofi -dmenu -i -no-custom -markup-rows -p Keybindings \
  -mesg 'Shortcut reference • Edit bindings in home/desktop/sway/keybindings.nix' \
  -lines 12 -theme-str 'window { width: 85%; }' >/dev/null || exit 0
