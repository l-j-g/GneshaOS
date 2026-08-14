#!/usr/bin/env bash
# Auto-brightness from IIO ambient light sensor via brightnessctl (logind D-Bus).
# Polls every 2s with exponential smoothing — same approach as illuminanced.

SENSOR=__ALS_SENSOR_PATH__
SMOOTH=0.3        # lower = smoother but slower to react
INTERVAL=2

# Map raw sensor value to brightness % (log scale, 10-100%)
# raw=1000 ~ 1 lux, raw=500000 ~ 500 lux office, raw=1500000 ~ 1500 lux daylight
to_pct() {
    awk -v r="$1" 'BEGIN {
        lux = r * 0.001
        if (lux < 1) lux = 1
        if (lux > 2000) lux = 2000
        printf "%.0f", 10 + 90 * log(lux) / log(2000)
    }'
}

# Seed the smoothed value from current brightness
current=$(brightnessctl -d __BACKLIGHT_DEVICE__ -m | cut -d, -f4 | tr -d %\n)
smoothed_raw=$(cat "$SENSOR" 2>/dev/null)
smoothed_pct=$(to_pct "$smoothed_raw")
echo "als-brightness: start (current=${current}%, lux~=$((smoothed_raw/1000)))"

while sleep "$INTERVAL"; do
    raw=$(cat "$SENSOR" 2>/dev/null) || continue
    target_pct=$(to_pct "$raw")

    # Exponential moving average
    smoothed_pct=$(awk -v s="$smoothed_pct" -v t="$target_pct" -v a="$SMOOTH" \
        'BEGIN { printf "%.0f", s + a * (t - s) }')

    brightnessctl -q set "${smoothed_pct}%"
done
