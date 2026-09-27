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
  : > "$CASE_DIR/events"
  : > "$CASE_DIR/gtk-mode"
  : > "$CASE_DIR/sway-mode"
  : > "$CASE_DIR/systemctl-mode"
  export SWAYSOCK="$CASE_DIR/sway-ipc.sock"
  : > "$SWAYSOCK"

  cat > "$CASE_DIR/bin/gtklock" <<'STUB'
#!/usr/bin/env bash
printf 'gtklock %s\n' "$*" >> "$CASE_DIR/calls"
printf 'gtk-start %s\n' "$(date +%s%N)" >> "$CASE_DIR/events"
case $(cat "$CASE_DIR/gtk-mode") in
  callback)
    # Invoke the command supplied as gtklock's post-lock callback. This models
    # acknowledgment only after the locker has acquired the compositor lock.
    for ((i=1; i <= $#; i++)); do
      if [[ ${!i} == --post-lock-command ]]; then
        next=$((i + 1))
        sleep "${READY_DELAY:-0.2}"
        printf 'gtklock-ready %s\n' "$(date +%s%N)" >> "$CASE_DIR/events"
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
printf 'sway-start %s\n' "$(date +%s%N)" >> "$CASE_DIR/events"
case $(cat "$CASE_DIR/sway-mode") in
  ready)
    # The test stub reports readiness through the supplied FD, as swaylock
    # does after locking the compositor.
    for ((i=1; i <= $#; i++)); do
      if [[ ${!i} == --ready-fd ]]; then
        next=$((i + 1))
        sleep "${READY_DELAY:-0.2}"
        printf '\n' >&"${!next}"
        printf 'swaylock-ready %s\n' "$(date +%s%N)" >> "$CASE_DIR/events"
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
if [[ ${1:-} == suspend ]]; then
  printf 'suspend %s\n' "$(date +%s%N)" >> "$CASE_DIR/events"
fi
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

run_lock_operation() {
  source "$helper"
  if declare -F gnesha_lock_and_suspend >/dev/null; then
    gnesha_lock_and_suspend
  else
    gnesha_lock_acquire
  fi
}

assert_acquisition_after_readiness() {
  local ordering
  ordering=$(awk '
    /^(gtklock|swaylock)-ready / { if ($2 > latest_ready) latest_ready=$2 }
    /^acquire-return / { if (!earliest_return || $2 < earliest_return) earliest_return=$2; returns++ }
    END { if (returns && latest_ready && earliest_return > latest_ready) print "ok" }
  ' "$CASE_DIR/events")
  [[ $ordering == ok ]] || fail 'acquisition did not return after a recorded readiness event'
}

assert_suspend_after_readiness() {
  local ready suspend suspend_calls
  suspend=$(awk '/^suspend / { print $2 }' "$CASE_DIR/events")
  if ( source "$helper"; declare -F gnesha_lock_and_suspend >/dev/null ); then
    suspend_calls=$(grep -c '^systemctl suspend\( \|$\)' "$CASE_DIR/calls" || true)
    [[ $suspend_calls == 1 ]] || fail "lock-and-suspend must issue exactly one suspend request, saw ${suspend_calls:-0}"
    [[ $(grep -c '^suspend ' "$CASE_DIR/events" || true) == 1 ]] || fail 'lock-and-suspend did not record exactly one suspend event'
    [[ -n $suspend ]] || fail 'lock-and-suspend did not record a suspend event'
  else
    [[ -z $suspend ]] && return 0
  fi
  ready=$(awk '/^(gtklock|swaylock)-ready / { if ($2 > latest) latest=$2 } END { print latest+0 }' "$CASE_DIR/events")
  [[ -n $ready && $suspend -gt $ready ]] || fail 'suspend was requested before lock readiness'
}

timed_lock_operation() {
  local status ended
  set +e
  run_lock_operation
  status=$?
  set -e
  ended=$(date +%s%N)
  printf 'acquire-return %s\n' "$ended" >> "$CASE_DIR/events"
  return "$status"
}

assert_call_count() {
  local expected=$1 actual
  actual=$(grep -Ec '^(gtklock|swaylock) ' "$CASE_DIR/calls" || true)
  [[ ${actual:-0} == "$expected" ]] || fail "expected $expected locker launches, saw ${actual:-0}"
}

new_case gtklock-callback
echo callback > "$CASE_DIR/gtk-mode"
echo fail > "$CASE_DIR/sway-mode"
timed_lock_operation || fail 'gtklock callback acknowledgment was rejected'
assert_acquisition_after_readiness
assert_suspend_after_readiness
assert_call_count 1
[[ $(grep -c '^gtklock ' "$CASE_DIR/calls") == 1 ]] || fail 'gtklock was not the acknowledged locker'
printf 'ok - gtklock callback acknowledgment\n'

new_case swaylock-fallback
echo timeout > "$CASE_DIR/gtk-mode"
echo ready > "$CASE_DIR/sway-mode"
timed_lock_operation || fail 'swaylock readiness after gtklock timeout was rejected'
read -r gtk_started sway_started returned < <(awk '
  /^gtk-start / { gtk=$2 }
  /^sway-start / { sway=$2 }
  /^acquire-return / { returned=$2 }
  END { print gtk, sway, returned }
' "$CASE_DIR/events")
gtk_elapsed_ms=$(( (sway_started - gtk_started) / 1000000 ))
total_elapsed_ms=$(( (returned - gtk_started) / 1000000 ))
(( gtk_elapsed_ms <= 5500 )) || fail "gtklock attempt exceeded 5 seconds plus 500ms tolerance (${gtk_elapsed_ms}ms)"
(( total_elapsed_ms <= 10500 )) || fail "combined gtklock and swaylock attempt exceeded 10 seconds plus 500ms tolerance (${total_elapsed_ms}ms)"
assert_acquisition_after_readiness
assert_suspend_after_readiness
assert_call_count 2
printf 'ok - gtklock timeout followed by swaylock readiness\n'

new_case dual-failure
echo fail > "$CASE_DIR/gtk-mode"
echo fail > "$CASE_DIR/sway-mode"
if timed_lock_operation; then fail 'both lockers failing unexpectedly reported readiness'; fi
assert_call_count 2
if grep -q '^systemctl .*suspend' "$CASE_DIR/calls"; then fail 'suspend was requested after both lockers failed'; fi
if grep -q '^suspend ' "$CASE_DIR/events"; then fail 'suspend event followed dual locker failure'; fi
printf 'ok - both lockers failing leaves system awake\n'

new_case stale-ack
echo timeout > "$CASE_DIR/gtk-mode"
echo fail > "$CASE_DIR/sway-mode"
touch "$XDG_RUNTIME_DIR/gnesha-lock.ack"
if timed_lock_operation; then fail 'stale acknowledgment marker was accepted'; fi
if grep -q '^systemctl .*suspend' "$CASE_DIR/calls" || grep -q '^suspend ' "$CASE_DIR/events"; then fail 'suspend was requested with stale acknowledgment state'; fi
printf 'ok - stale acknowledgment marker rejected\n'

new_case no-sway
unset SWAYSOCK
echo callback > "$CASE_DIR/gtk-mode"
if timed_lock_operation; then fail 'lock acquisition succeeded without SWAYSOCK'; fi
[[ ! -s "$CASE_DIR/calls" ]] || fail 'a locker or system command ran without SWAYSOCK'
if grep -q '^systemctl .*suspend' "$CASE_DIR/calls" || grep -q '^suspend ' "$CASE_DIR/events"; then fail 'suspend was requested without SWAYSOCK'; fi
printf 'ok - no-Sway request fails without side effects\n'

new_case concurrent
echo callback > "$CASE_DIR/gtk-mode"
echo fail > "$CASE_DIR/sway-mode"
( timed_lock_operation ) & first=$!
( timed_lock_operation ) & second=$!
wait "$first" || fail 'first concurrent lock request failed'
wait "$second" || fail 'second concurrent lock request failed'
assert_acquisition_after_readiness
assert_suspend_after_readiness
assert_call_count 1
printf 'ok - simultaneous requests launch only one locker\n'
