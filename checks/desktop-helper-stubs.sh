#!/usr/bin/env bash
set -Eeuo pipefail

recorder=${1:?usage: desktop-helper-stubs.sh /path/to/recorder.sh /path/to/sway-help /build/test-root /path/to/recorder-stub.c}
sway_help=${2:?usage: desktop-helper-stubs.sh /path/to/recorder.sh /path/to/sway-help /build/test-root /path/to/recorder-stub.c}
test_root=${3:?usage: desktop-helper-stubs.sh /path/to/recorder.sh /path/to/sway-help /build/test-root /path/to/recorder-stub.c}
recorder_stub_source=${4:?usage: desktop-helper-stubs.sh /path/to/recorder.sh /path/to/sway-help /build/test-root /path/to/recorder-stub.c}
case "$test_root" in
  /tmp/gnesha-desktop-helper-check|/build/gnesha-desktop-helper-check|/build/*/gnesha-desktop-helper-check) ;;
  *) echo "refusing to use a runtime root outside the dedicated build fixture" >&2; exit 2 ;;
esac
[[ -f $recorder && -f $sway_help && -f $recorder_stub_source ]] || { echo 'desktop helper source is missing' >&2; exit 2; }

rm -rf -- "$test_root"
mkdir -p "$test_root/bin" "$test_root/runtime" "$test_root/home"
cc -O2 "$recorder_stub_source" -o "$test_root/wf-recorder-fixture"
export RECORDER_PROCESS_STUB="$test_root/wf-recorder-fixture"
stub_bin="$test_root/bin"
export SYSTEM_SLEEP=$(command -v sleep)
export TEST_ROOT="$test_root" STUB_LOG="$test_root/stub.log"
export PATH="$stub_bin:$PATH"
export XDG_RUNTIME_DIR="$test_root/runtime" HOME="$test_root/home"
first_pid=
recording_action_pid=
target_pid=
other_pid=

cat > "$stub_bin/notify-send" <<'STUB'
#!/bin/sh
printf 'notify: %s\n' "$*" >> "$STUB_LOG"
STUB
cat > "$stub_bin/xdg-user-dir" <<'STUB'
#!/bin/sh
printf '%s\n' "$VIDEO_DIR"
STUB
cat > "$stub_bin/slurp" <<'STUB'
#!/usr/bin/env bash
printf 'slurp\n' >> "$STUB_LOG"
if [ "${SLURP_BLOCK:-}" = yes ]; then
  : > "$SLURP_ENTERED"
  while [ ! -e "$SLURP_RELEASE" ]; do "$SYSTEM_SLEEP" 0.02; done
fi
if [ "${SLURP_RESULT:-select}" = cancel ]; then exit 1; fi
printf '10,20 640x480\n'
STUB
cat > "$stub_bin/sleep" <<'STUB'
#!/bin/sh
# Keep the countdown deterministic while allowing lock retries to yield.
if [ "${1:-}" = 1 ]; then exit 0; fi
exec "$SYSTEM_SLEEP" "$@"
STUB
cat > "$stub_bin/date" <<'STUB'
#!/bin/sh
printf 'fixture-time\n'
STUB
cat > "$stub_bin/wf-recorder" <<'STUB'
#!/bin/sh
out=
for arg do case "$arg" in --file=*) out=${arg#--file=} ;; esac; done
case "${RECORDER_MODE:-write}" in
  write) printf 'synthetic recording\n' > "$out"; exit 0 ;;
  empty) : > "$out"; exit 0 ;;
  fail) exit 17 ;;
  block) exec "$RECORDER_PROCESS_STUB" ;;
  *) exit 99 ;;
esac
STUB
cat > "$stub_bin/swaymsg" <<'STUB'
#!/bin/sh
printf '[{"name":"fixture-output"}]\n'
STUB
cat > "$stub_bin/jq" <<'STUB'
#!/bin/sh
# sway-help only needs the output-name query. The fixture returns a fixed name.
printf 'fixture-output\n'
STUB
cat > "$stub_bin/nwg-wrapper" <<'STUB'
#!/bin/sh
printf 'wrapper:%s\n' "$*" >> "$STUB_LOG"
exit 0
STUB
for stub in "$stub_bin"/*; do sed -i "1s|^#!.*$|#!$BASH|" "$stub"; done
chmod +x "$stub_bin"/*

assert_log() {
  grep -Fq -- "$1" "$STUB_LOG" || { echo "missing fixture event: $1" >&2; cat "$STUB_LOG" >&2; exit 1; }
}
reset_fixture() {
  rm -rf -- "$XDG_RUNTIME_DIR/gneshaos" "$test_root/videos" "$test_root/videos-a" "$test_root/videos-b"
  mkdir -p "$test_root/videos"
  : > "$STUB_LOG"
}
invoke_recorder() {
  local session=$1 videos=$2
  shift 2
  SWAYSOCK="/run/user/fixture/$session" WAYLAND_DISPLAY=fixture-wayland VIDEO_DIR="$videos" sh "$recorder" "$@"
}
process_is_live() {
  local state
  state=$(awk '/^State:/ { print $2; exit }' "/proc/$1/status" 2>/dev/null || true)
  [[ -n $state && $state != Z && $state != X ]]
}
cleanup_fixture() {
  if [[ -n ${SLURP_RELEASE:-} ]]; then : > "$SLURP_RELEASE"; fi
  local pid
  for pid in "${first_pid:-}" "${recording_action_pid:-}" "${target_pid:-}" "${other_pid:-}"; do
    [[ -n $pid ]] && kill -TERM "$pid" 2>/dev/null || true
  done
  for pid in "${first_pid:-}" "${recording_action_pid:-}" "${target_pid:-}" "${other_pid:-}"; do
    [[ -n $pid ]] && wait "$pid" 2>/dev/null || true
  done
}
trap cleanup_fixture EXIT

# Cancellation is a successful user action, creates no recording, and says so.
reset_fixture
export SLURP_RESULT=cancel RECORDER_MODE=write
if invoke_recorder cancel-session "$test_root/videos" >"$test_root/cancel.out" 2>&1; then :; else
  echo 'selection cancellation returned failure' >&2; exit 1
fi
assert_log 'Selection cancelled'
[[ ! -e "$test_root/videos/recording_fixture-time.webm" ]] || { echo 'cancelled selection created output' >&2; exit 1; }

# Non-zero recorder exit and a zero-byte successful exit are both failures.
for mode in fail empty; do
  reset_fixture
  export SLURP_RESULT=select RECORDER_MODE=$mode
if invoke_recorder "failure-$mode" "$test_root/videos" >"$test_root/$mode.out" 2>&1; then
    echo "recorder $mode mode returned success (RECORDER_MODE=$RECORDER_MODE)" >&2
    cat "$STUB_LOG" >&2
    cat "$test_root/$mode.out" >&2
    exit 1
  fi
  assert_log 'Failed (exit '
  if grep -Fq 'Saved ' "$STUB_LOG"; then echo "recorder $mode mode announced Saved" >&2; exit 1; fi
done

# A zero exit with a non-empty output is the only successful save path.
reset_fixture
export SLURP_RESULT=select RECORDER_MODE=write
invoke_recorder success-session "$test_root/videos" >"$test_root/success.out" 2>&1
assert_log "Saved $test_root/videos/recording_fixture-time.webm"
[[ -s "$test_root/videos/recording_fixture-time.webm" ]] || { echo 'successful recording output is absent or empty' >&2; exit 1; }
[[ ! -e "$XDG_RUNTIME_DIR/gneshaos/success-session/recorder/recorder.pid" ]] || { echo 'recorder PID state was not cleaned up' >&2; exit 1; }

# Escape's stop-only action with no recording must not open a region selector
# or fall through to starting a new recording.
reset_fixture
export SLURP_RESULT=select RECORDER_MODE=write
if invoke_recorder stop-empty-session "$test_root/videos" --stop >"$test_root/stop-empty.out" 2>&1; then :; else
  echo 'stop-only action with no recording returned failure' >&2; cat "$test_root/stop-empty.out" >&2; exit 1
fi
if grep -Fq 'slurp' "$STUB_LOG" || grep -Fq 'wf-recorder' "$STUB_LOG"; then
  echo 'stop-only action with no recording entered the start flow' >&2; cat "$STUB_LOG" >&2; exit 1
fi
assert_log 'No recording is active in this Sway session'

# A stale PID reused by an unrelated process must not be signaled.
reset_fixture
export SLURP_RESULT=select RECORDER_MODE=write
session_state="$XDG_RUNTIME_DIR/gneshaos/stop-target-session/recorder"
mkdir -p "$session_state"
"$SYSTEM_SLEEP" 30 &
other_pid=$!
printf '%s\n' "$other_pid" > "$session_state/recorder.pid"
if invoke_recorder stop-target-session "$test_root/videos" --stop >"$test_root/stop-target.out" 2>&1; then :; else
  kill -TERM "$other_pid" 2>/dev/null || true
  echo 'stop-only action could not stop the session recorder' >&2; cat "$test_root/stop-target.out" >&2; exit 1
fi
if ! process_is_live "$other_pid"; then
  wait "$other_pid" 2>/dev/null || true
  other_pid=
  echo 'stop action signaled a stale PID that now belongs to another process' >&2; exit 1
fi
kill -TERM "$other_pid"
wait "$other_pid" 2>/dev/null || true
other_pid=
assert_log 'No recording is active in this Sway session'
[[ ! -e "$session_state/recorder.pid" ]] || { echo 'stale session PID file was not removed' >&2; exit 1; }

# A stale PID must not signal a live recorder process from another Sway session.
reset_fixture
export SLURP_RESULT=select RECORDER_MODE=write
session_state="$XDG_RUNTIME_DIR/gneshaos/reused-pid-session/recorder"
mkdir -p "$session_state"
"$RECORDER_PROCESS_STUB" &
other_pid=$!
for _ in $(seq 1 200); do
  [[ $(cat "/proc/$other_pid/comm" 2>/dev/null || true) = wf-recorder ]] && break
  "$SYSTEM_SLEEP" 0.01
done
[[ $(cat "/proc/$other_pid/comm" 2>/dev/null || true) = wf-recorder ]] || { echo 'synthetic other-session recorder did not start' >&2; exit 1; }
printf '%s 0\n' "$other_pid" > "$session_state/recorder.pid"
if ! invoke_recorder reused-pid-session "$test_root/videos" --stop >"$test_root/reused-pid-stop.out" 2>&1; then
  echo 'stop-only action failed on a stale same-name PID' >&2; cat "$test_root/reused-pid-stop.out" >&2; exit 1
fi
if ! process_is_live "$other_pid"; then
  wait "$other_pid" 2>/dev/null || true
  other_pid=
  echo 'stop action signaled a same-name process with a different start time' >&2; exit 1
fi
printf '%s\n' "$other_pid" > "$session_state/recorder.pid"
if ! invoke_recorder reused-pid-session "$test_root/videos" --stop >"$test_root/reused-pid-legacy-stop.out" 2>&1; then
  echo 'stop-only action failed on a legacy PID file' >&2; cat "$test_root/reused-pid-legacy-stop.out" >&2; exit 1
fi
if ! process_is_live "$other_pid"; then
  wait "$other_pid" 2>/dev/null || true
  other_pid=
  echo 'stop action signaled a same-named process from another session' >&2; exit 1
fi
kill -TERM "$other_pid"
wait "$other_pid" 2>/dev/null || true
other_pid=
assert_log 'No recording is active in this Sway session'

# Stopping one active recording leaves a same-named process from another
# session untouched. Both recorder processes are synthetic fixture children.
reset_fixture
export SLURP_RESULT=select RECORDER_MODE=block
session_state="$XDG_RUNTIME_DIR/gneshaos/live-stop-session/recorder"
SWAYSOCK=/run/user/fixture/live-stop-session VIDEO_DIR="$test_root/videos" sh "$recorder" >"$test_root/live-stop-start.out" 2>&1 &
recording_action_pid=$!
target_pid=
for _ in $(seq 1 200); do
  if [[ -s "$session_state/recorder.pid" ]]; then
    target_pid=$(awk '{ print $1 }' "$session_state/recorder.pid")
    if [[ -r "/proc/$target_pid/comm" ]] && [[ $(cat "/proc/$target_pid/comm") = wf-recorder ]] && [[ ! -d "$session_state/lock" ]]; then
      break
    fi
  fi
  "$SYSTEM_SLEEP" 0.01
done
if [[ -z "$target_pid" ]] || [[ ! -r "/proc/$target_pid/comm" ]] || [[ $(cat "/proc/$target_pid/comm") != wf-recorder ]] || [[ -d "$session_state/lock" ]]; then
  kill -TERM "$recording_action_pid" "$target_pid" 2>/dev/null || true
  echo 'fixture recorder did not reach its active state' >&2; cat "$test_root/live-stop-start.out" >&2; exit 1
fi
"$RECORDER_PROCESS_STUB" &
other_pid=$!
for _ in $(seq 1 200); do
  [[ $(cat "/proc/$other_pid/comm" 2>/dev/null || true) = wf-recorder ]] && break
  "$SYSTEM_SLEEP" 0.01
done
if ! invoke_recorder live-stop-session "$test_root/videos" --stop >"$test_root/live-stop.out" 2>&1; then
  kill -TERM "$recording_action_pid" "$target_pid" "$other_pid" 2>/dev/null || true
  echo 'stop-only action failed for the active session recorder' >&2; cat "$test_root/live-stop.out" >&2; exit 1
fi
if wait "$recording_action_pid"; then :; else
  recording_status=$?
  kill -TERM "$other_pid" 2>/dev/null || true
  wait "$other_pid" 2>/dev/null || true
  echo "recording wrapper failed to report the requested stop (exit $recording_status)" >&2
  cat "$test_root/live-stop-start.out" "$test_root/live-stop.out" >&2
  cat "$STUB_LOG" >&2
  exit 1
fi
recording_action_pid=
target_pid=
if ! process_is_live "$other_pid"; then
  wait "$other_pid" 2>/dev/null || true
  other_pid=
  echo 'session stop action also stopped another same-named recorder process' >&2; exit 1
fi
kill -TERM "$other_pid"
wait "$other_pid" 2>/dev/null || true
other_pid=
assert_log "Stopping this session's recording"
[[ ! -e "$session_state/recorder.pid" ]] || { echo 'stopped recorder PID state was not cleaned up' >&2; exit 1; }

# Hold one recorder action inside the stub selection UI. Another action in the
# same Sway session must observe the lock; a different session remains usable.
reset_fixture
export SLURP_RESULT=select RECORDER_MODE=write
export SLURP_BLOCK=yes SLURP_ENTERED="$test_root/slurp.entered" SLURP_RELEASE="$test_root/slurp.release"
SWAYSOCK=/run/user/fixture/locked-session VIDEO_DIR="$test_root/videos-a" sh -x "$recorder" >"$test_root/first.out" 2>&1 &
first_pid=$!
for _ in $(seq 1 200); do [[ -e $SLURP_ENTERED ]] && break; "$SYSTEM_SLEEP" 0.01; done
[[ -e $SLURP_ENTERED ]] || { echo 'first recorder did not reach the blocked selection stub' >&2; exit 1; }
if invoke_recorder locked-session "$test_root/videos-b" >"$test_root/second.out" 2>&1; then
  echo 'concurrent same-session recorder action unexpectedly succeeded' >&2; exit 1
fi
assert_log 'Another recording action is already in progress'
unset SLURP_BLOCK
invoke_recorder independent-session "$test_root/videos-b" >"$test_root/other-session.out" 2>&1
: > "$SLURP_RELEASE"
wait "$first_pid"
first_pid=
[[ -s "$test_root/videos-a/recording_fixture-time.webm" && -s "$test_root/videos-b/recording_fixture-time.webm" ]] || {
  echo 'independent session recording did not complete in its own output directory' >&2; exit 1;
}
[[ ! -e "$XDG_RUNTIME_DIR/gneshaos/locked-session/recorder/lock" && ! -e "$XDG_RUNTIME_DIR/gneshaos/independent-session/recorder/lock" ]] || {
  echo 'recorder session lock was not cleaned up' >&2; exit 1;
}
unset SLURP_ENTERED SLURP_RELEASE

# The keybinding overlay stores wrapper PIDs under the derived session key.
# Fast-exiting stubs ensure this fixture never signals any process.
reset_fixture
SWAYSOCK=/run/user/fixture/help-one sh "$sway_help"
SWAYSOCK=/run/user/fixture/help-two sh "$sway_help"
[[ -s "$XDG_RUNTIME_DIR/gneshaos/help-one/sway-help/wrapper-pids" ]] || { echo 'first session overlay state missing' >&2; exit 1; }
[[ -s "$XDG_RUNTIME_DIR/gneshaos/help-two/sway-help/wrapper-pids" ]] || { echo 'second session overlay state missing' >&2; exit 1; }
grep -Fq 'fixture-output' "$STUB_LOG" || { echo 'overlay wrapper stub did not run' >&2; exit 1; }

echo 'desktop helper stub checks passed'
