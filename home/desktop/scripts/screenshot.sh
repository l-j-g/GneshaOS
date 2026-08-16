#!/bin/sh
# Capture a screenshot, save it, and optionally upload it.
# Usage: screenshot.sh output|area|upload-output|upload-area

set -eu

mode=${1:-}
timestamp=$(date +'screenshot_%Y%m%d-%H%M%S')
file="__SCREENSHOT_DIR__/$timestamp.png"
mkdir -p "$(dirname "$file")"

case "$mode" in
    output)
        grimshot save output - | swappy -f - -o "$file"
        ;;
    area)
        grimshot save area - | swappy -f - -o "$file"
        ;;
    upload-output)
        grimshot save output "$file"
        ;;
    upload-area)
        grimshot save area "$file"
        ;;
    *)
        echo "Usage: screenshot.sh output|area|upload-output|upload-area" >&2
        exit 2
        ;;
esac

if [ ! -s "$file" ]; then
    notify-send "Screenshot" "No screenshot was saved."
    exit 1
fi

case "$mode" in
    upload-*)
        url=$(curl -fsS -F "file=@$file;filename=$(basename "$file")" "__SCREENSHOT_UPLOAD_URL__")
        printf '%s\n' "$url" | wl-copy
        notify-send "Screenshot uploaded" "$url"
        ;;
    *)
        notify-send "Screenshot saved" "$file"
        ;;
esac
