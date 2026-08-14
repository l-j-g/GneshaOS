#!/bin/sh
# scale.sh [up|down|default] — adjust scaling of the focused output.
name=$(swaymsg -t get_outputs | jq -r '.[] | select(.focused == true) | .name')
[ -n "$name" ] || exit 1
current=$(swaymsg -t get_outputs | jq -r '.[] | select(.focused == true) | .scale')

case "${1:-}" in
    up)      next=$(awk -v c="$current" 'BEGIN { printf "%.2f", c + 0.25 }') ;;
    down)    next=$(awk -v c="$current" 'BEGIN { printf "%.2f", c - 0.25 }') ;;
    default) next=__DEFAULT_SCALE__ ;;
    *)       echo "$current"; exit 0 ;;
esac
next=$(awk -v n="$next" 'BEGIN { print (n < 1 ? 1 : n) }')
swaymsg output "$name" scale "$next"
