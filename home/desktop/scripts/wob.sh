#!/bin/sh
# wob.sh <accent> <background> [value]
# Show a wob on-screen bar. Value comes from $3 or stdin (percent 0-100).
command -v wob >/dev/null 2>&1 || exit 0
accent="${1:-#00ff9c}"
background="${2:-#050805}"
value="$3"
[ -n "$value" ] || value=$(cat)
[ -n "$value" ] || exit 0
value=$(printf '%s' "$value" | tr -dc '0-9')
[ -n "$value" ] || value=0
[ "$value" -gt 100 ] && value=100
printf '%s\n' "$value" | wob -b "${background#\#}" -f "${accent#\#}"
