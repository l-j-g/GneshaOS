#!/usr/bin/env bash
set -Eeuo pipefail

recorder=${1:?usage: desktop-helper-stubs.sh /path/to/recorder.sh /path/to/sway-help /build/test-root}
sway_help=${2:?usage: desktop-helper-stubs.sh /path/to/recorder.sh /path/to/sway-help /build/test-root}
test_root=${3:?usage: desktop-helper-stubs.sh /path/to/recorder.sh /path/to/sway-help /build/test-root}
case "$test_root" in
  /tmp/gnesha-desktop-helper-check|/build/gnesha-desktop-helper-check|/build/*/gnesha-desktop-helper-check) ;;
  *) echo "refusing to use a runtime root outside the dedicated build fixture" >&2; exit 2 ;;
esac
[[ -f $recorder && -f $sway_help ]] || { echo 'desktop helper source is missing' >&2; exit 2; }

rm -rf -- "$test_root"
mkdir -p "$test_root/bin" "$test_root/runtime" "$test_root/home"
stub_bin="$test_root/bin"
export SYSTEM_SLEEP=$(command -v sleep)
export TEST_ROOT="$test_root" STUB_LOG="$test_root/stub.log"
export PATH="$stub_bin:$PATH"
export XDG_RUNTIME_DIR="$test_root/runtime" HOME="$test_root/home"

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
# Recorder countdown is a no-op in the deterministic fixture.
exit 0
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
