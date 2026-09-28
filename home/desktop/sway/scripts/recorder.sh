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
process_starttime() {
    proc_stat_line=$(cat "/proc/$1/stat" 2>/dev/null) || return 1
    proc_stat_fields=${proc_stat_line##*) }
    set -- $proc_stat_fields
    [ "$#" -ge 20 ] || return 1
    shift 19
    case "${1:-}" in ""|*[!0-9]*) return 1 ;; esac
    printf '%s\n' "$1"
}
case "${1:-}" in
    ""|-a|--stop) ;;
    *) notify-send "Recording" "Usage: recorder.sh [-a|--stop]"; exit 2 ;;
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
    recorder_pid=
    recorder_start=
    IFS=' ' read -r recorder_pid recorder_start < "$pidfile" || true
    case "$recorder_pid:$recorder_start" in
        *[!0-9:]*|:*) recorder_pid=; recorder_start= ;;
    esac
    current_start=
    if [ -n "$recorder_pid" ] && [ -n "$recorder_start" ]; then
        current_start=$(process_starttime "$recorder_pid" || true)
    fi
    if [ -n "$current_start" ] && [ "$current_start" = "$recorder_start" ] \
        && [ -r "/proc/$recorder_pid/comm" ] && [ "$(cat "/proc/$recorder_pid/comm")" = wf-recorder ]; then
        : > "$stopfile"
        if kill -INT "$recorder_pid"; then
            notify-send "Recording" "Stopping this session's recording"
            exit 0
        fi
        rm -f "$stopfile"
    fi
    rm -f "$pidfile" "$stopfile"
fi

if [ "${1:-}" = --stop ]; then
    notify-send "Recording" "No recording is active in this Sway session"
    exit 0
fi
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
recorder_start=$(process_starttime "$recorder_pid" || true)
if [ -n "$recorder_start" ]; then
    printf '%s %s\n' "$recorder_pid" "$recorder_start" > "$pidfile"
else
    printf '%s\n' "$recorder_pid" > "$pidfile"
fi
unlock
trap - EXIT HUP INT TERM
wait "$recorder_pid"
recorder_status=$?

lock_attempt=0
while ! mkdir "$lock" 2>/dev/null; do
    lock_attempt=$((lock_attempt + 1))
    if [ "$lock_attempt" -ge 50 ]; then
        notify-send "Recording" "Finished, but session state could not be updated"
        exit 1
    fi
    sleep 0.02
done
saved_pid=
saved_start=
IFS=' ' read -r saved_pid saved_start < "$pidfile" 2>/dev/null || true
if [ "$saved_pid" = "$recorder_pid" ] && [ "$saved_start" = "$recorder_start" ]; then rm -f "$pidfile"; fi
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
