#!/usr/bin/env bash
set -euo pipefail

helper=${1:?usage: lock-readiness-stubs.sh HELPER}
if [[ ! -f $helper ]]; then
  printf 'lock-readiness fixture: helper not found: %s\n' "$helper" >&2
  exit 2
fi

helper=$(realpath "$helper")
fixture_root=$(mktemp -d)
trap 'rm -rf "$fixture_root"' EXIT

fail() {
  printf 'not ok - %s\n' "$*" >&2
  exit 1
}

new_case() {
  CASE_DIR="$fixture_root/$1"
  mkdir -p "$CASE_DIR/bin" "$CASE_DIR/runtime"
  export CASE_DIR XDG_RUNTIME_DIR="$CASE_DIR/runtime" PATH="$CASE_DIR/bin:$PATH"
  : > "$CASE_DIR/calls"
  : > "$CASE_DIR/gtk-mode"
  : > "$CASE_DIR/sway-mode"
  : > "$CASE_DIR/systemctl-mode"
  export SWAYSOCK="$CASE_DIR/sway-ipc.sock"
  : > "$SWAYSOCK"

  cat > "$CASE_DIR/bin/gtklock" <<'STUB'
#!/usr/bin/env bash
printf 'gtklock %s\n' "$*" >> "$CASE_DIR/calls"
case $(cat "$CASE_DIR/gtk-mode") in
  callback)
    # Invoke the command supplied as gtklock's post-lock callback. This models
    # acknowledgment only after the locker has acquired the compositor lock.
    for ((i=1; i <= $#; i++)); do
      if [[ ${!i} == --post-lock-command ]]; then
        next=$((i + 1))
        bash -c "${!next}"
        break
      fi
    done
    ;;
  timeout) sleep 30 ;;
  fail) exit 1 ;;
esac
STUB
  cat > "$CASE_DIR/bin/swaylock" <<'STUB'
#!/usr/bin/env bash
printf 'swaylock %s\n' "$*" >> "$CASE_DIR/calls"
case $(cat "$CASE_DIR/sway-mode") in
  ready)
    # The test stub reports readiness through the supplied FD, as swaylock
    # does after locking the compositor.
    for ((i=1; i <= $#; i++)); do
      if [[ ${!i} == --ready-fd ]]; then
        next=$((i + 1))
        printf '\n' >&"${!next}"
        break
      fi
    done
    sleep 30
    ;;
  fail) exit 1 ;;
  no-ready) sleep 30 ;;
esac
STUB
  cat > "$CASE_DIR/bin/systemctl" <<'STUB'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >> "$CASE_DIR/calls"
STUB
  cat > "$CASE_DIR/bin/busctl" <<'STUB'
#!/usr/bin/env bash
printf 'busctl %s\n' "$*" >> "$CASE_DIR/calls"
exit 1
STUB
  cat > "$CASE_DIR/bin/dbus-send" <<'STUB'
#!/usr/bin/env bash
printf 'dbus-send %s\n' "$*" >> "$CASE_DIR/calls"
STUB
  chmod +x "$CASE_DIR/bin/"*
}

run_acquire() {
  source "$helper"
  gnesha_lock_acquire
}

assert_call_count() {
  local expected=$1 actual
  actual=$(grep -Ec '^(gtklock|swaylock) ' "$CASE_DIR/calls" || true)
  [[ ${actual:-0} == "$expected" ]] || fail "expected $expected locker launches, saw ${actual:-0}"
}

new_case gtklock-callback
echo callback > "$CASE_DIR/gtk-mode"
echo fail > "$CASE_DIR/sway-mode"
run_acquire || fail 'gtklock callback acknowledgment was rejected'
assert_call_count 1
[[ $(grep -c '^gtklock ' "$CASE_DIR/calls") == 1 ]] || fail 'gtklock was not the acknowledged locker'
printf 'ok - gtklock callback acknowledgment\n'

new_case swaylock-fallback
echo timeout > "$CASE_DIR/gtk-mode"
echo ready > "$CASE_DIR/sway-mode"
run_acquire || fail 'swaylock readiness after gtklock timeout was rejected'
assert_call_count 2
printf 'ok - gtklock timeout followed by swaylock readiness\n'

new_case dual-failure
echo fail > "$CASE_DIR/gtk-mode"
echo fail > "$CASE_DIR/sway-mode"
if run_acquire; then fail 'both lockers failing unexpectedly reported readiness'; fi
assert_call_count 2
if grep -q '^systemctl .*suspend' "$CASE_DIR/calls"; then fail 'suspend was requested after both lockers failed'; fi
printf 'ok - both lockers failing leaves system awake\n'

new_case stale-ack
echo timeout > "$CASE_DIR/gtk-mode"
echo fail > "$CASE_DIR/sway-mode"
touch "$XDG_RUNTIME_DIR/gnesha-lock.ack"
if run_acquire; then fail 'stale acknowledgment marker was accepted'; fi
printf 'ok - stale acknowledgment marker rejected\n'

new_case no-sway
unset SWAYSOCK
echo callback > "$CASE_DIR/gtk-mode"
if run_acquire; then fail 'lock acquisition succeeded without SWAYSOCK'; fi
[[ ! -s "$CASE_DIR/calls" ]] || fail 'a locker or system command ran without SWAYSOCK'
printf 'ok - no-Sway request fails without side effects\n'

new_case concurrent
echo callback > "$CASE_DIR/gtk-mode"
echo fail > "$CASE_DIR/sway-mode"
( run_acquire ) & first=$!
( run_acquire ) & second=$!
wait "$first" || fail 'first concurrent lock request failed'
wait "$second" || fail 'second concurrent lock request failed'
assert_call_count 1
printf 'ok - simultaneous requests launch only one locker\n'
