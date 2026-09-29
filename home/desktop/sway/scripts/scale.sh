#!/bin/sh
# scale.sh [up|down|default|show] — adjust scaling through the display manager.
set -eu
output=$(swaymsg -t get_outputs | jq -c '.[] | select(.focused == true)')
name=$(printf '%s\n' "$output" | jq -r '.name')
[ -n "$name" ] || exit 1
current=$(printf '%s\n' "$output" | jq -r '.scale')

case "${1:-}" in
    up)      next=$(awk -v c="$current" 'BEGIN { printf "%.2f", c + 0.25 }') ;;
    down)    next=$(awk -v c="$current" 'BEGIN { printf "%.2f", c - 0.25 }') ;;
    default) next=__DEFAULT_SCALE__ ;;
    show)    next=$current ;;
    *)       echo "$current"; exit 0 ;;
esac
next=$(awk -v n="$next" 'BEGIN { print (n < 1 ? 1 : n) }')
if [ "$1" != show ]; then
    # Direct Sway changes are immediately reverted by way-displays.
    way-displays --set SCALE "$name" "$next" >/dev/null
fi
actual=$(swaymsg -t get_outputs | jq -r --arg name "$name" '.[] | select(.name == $name) | .scale')
label=$(awk -v scale="$actual" 'BEGIN { printf "%g%s", scale, (scale == int(scale) ? ".0" : "") }')
notify-send -a 'Sway scale' -t 2500 "Sway scale: $label"
