#!/usr/bin/env sh
# Toggle this session's screen recording. Usage: recorder.sh [-a]
set -u

runtime=${XDG_RUNTIME_DIR:-}
if [ -z "$runtime" ] || [ ! -d "$runtime" ]; then
    notify-send "Recording" "No session runtime directory is available"
    exit 1
fi
session=${SWAYSOCK##*/}
[ -n "$session" ] || session=${WAYLAND_DISPLAY:-}
case "$session" in
    ""|*[!A-Za-z0-9_.-]*) notify-send "Recording" "No safe Sway session identifier is available"; exit 1 ;;
esac
state="$runtime/gneshaos/$session/recorder"
mkdir -p "$state" || exit 1
chmod 700 "$state"

# mkdir is an atomic per-session lock. A concurrent start/stop gets a clear
# result instead of racing the pid file or affecting another session.
lock="$state/lock"
if ! mkdir "$lock" 2>/dev/null; then
    notify-send "Recording" "Another recording action is already in progress"
    exit 1
fi
unlock() { rmdir "$lock" 2>/dev/null || true; }
trap unlock EXIT HUP INT TERM

pidfile="$state/recorder.pid"
stopfile="$state/stop-requested"
if [ -s "$pidfile" ]; then
    recorder_pid=$(cat "$pidfile")
    if [ -r "/proc/$recorder_pid/comm" ] && [ "$(cat "/proc/$recorder_pid/comm")" = wf-recorder ]; then
        : > "$stopfile"
        if kill -INT "$recorder_pid"; then
            notify-send "Recording" "Stopping this session's recording"
            exit 0
        fi
        rm -f "$stopfile"
    fi
    rm -f "$pidfile" "$stopfile"
fi

case "${1:-}" in
    ""|-a) ;;
    *) notify-send "Recording" "Usage: recorder.sh [-a]"; exit 2 ;;
esac
target=$(xdg-user-dir VIDEOS 2>/dev/null || printf '%s\n' "$HOME/Videos")
if ! mkdir -p "$target"; then
    notify-send "Recording" "Could not create $target"
    exit 1
fi
timestamp=$(date +'%Y%m%d-%H%M%S-%N')
file="$target/recording_$timestamp.webm"

notify-send "Recording" "Select a region"
if ! area=$(slurp); then
    notify-send "Recording" "Selection cancelled"
    exit 0
fi
notify-send "Recording" "Starting in 1 second"
sleep 1

rm -f "$stopfile"
if [ "${1:-}" = -a ]; then
    wf-recorder --audio -g "$area" --file="$file" &
else
    wf-recorder -g "$area" --file="$file" &
fi
recorder_pid=$!
printf '%s\n' "$recorder_pid" > "$pidfile"
unlock
trap - EXIT HUP INT TERM
wait "$recorder_pid"
recorder_status=$?

if ! mkdir "$lock" 2>/dev/null; then
    notify-send "Recording" "Finished, but session state could not be updated"
    exit 1
fi
if [ "$(cat "$pidfile" 2>/dev/null || true)" = "$recorder_pid" ]; then
    rm -f "$pidfile"
fi
was_stopped=false
if [ -e "$stopfile" ]; then was_stopped=true; fi
rm -f "$stopfile"
unlock

if [ "$was_stopped" = true ]; then
    if [ -f "$file" ]; then notify-send "Recording" "Stopped; partial file: $file";
    else notify-send "Recording" "Stopped"; fi
elif [ "$recorder_status" -eq 0 ] && [ -s "$file" ]; then
    notify-send "Recording" "Saved $file"
else
    notify-send "Recording" "Failed (exit $recorder_status); output was not saved"
    exit 1
fi
