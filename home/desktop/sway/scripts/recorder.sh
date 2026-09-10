#!/usr/bin/env sh
# Screen recording toggle (Manjaro recorder.sh, adapted for Nix).
# Usage: recorder.sh [-a]   (-a = record audio too)

if pgrep wf-recorder >/dev/null; then
    pkill -SIGINT wf-recorder
    notify-send "Recording" "Stopped"
    exit 0
fi

target=$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")
mkdir -p "$target"
timestamp=$(date +'recording_%Y%m%d-%H%M%S')

notify-send "Recording" "Select a region" -t 1000
area=$(slurp) || exit 1

notify-send "Recording" "Starting in 3..." -t 1000
sleep 1

file="$target/$timestamp.webm"
if [ "$1" = "-a" ]; then
    wf-recorder --audio -g "$area" --file="$file"
else
    wf-recorder -g "$area" --file="$file"
fi

notify-send "Recording" "Saved $file"
