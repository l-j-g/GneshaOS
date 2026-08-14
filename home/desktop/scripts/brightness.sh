#!/bin/sh
# brightness.sh [up|down] — adjust brightness and print the new relative value
# (consumed by wob.sh for the on-screen bar).
current_rel() {
    awk -v cur="$(brightnessctl get)" -v max="$(brightnessctl max)" 'BEGIN { printf "%d", cur * 100 / max }'
}
factor=3
step=$(( $(brightnessctl max) * factor / 100 ))
[ "$step" -lt 1 ] && step=1

case "${1:-}" in
    down)
        if [ "$(current_rel)" -le "$factor" ]; then
            brightnessctl --quiet set 1
        else
            brightnessctl --quiet set "${step}-"
        fi
        ;;
    up)
        brightnessctl --quiet set "${step}+"
        ;;
esac

current_rel
