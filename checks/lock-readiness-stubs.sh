#!/usr/bin/env bash
# shellcheck disable=SC1090
set -euo pipefail

helper=${1:?usage: lock-readiness-stubs.sh HELPER}
if [[ ! -f $helper ]]; then
  printf 'lock-readiness fixture: helper not found: %s\n' "$helper" >&2
  exit 2
fi

helper=$(realpath "$helper")
export GNESHA_LOCK_HELPER=$helper
fixture_root=$(mktemp -d)
trap 'rm -rf "$fixture_root"' EXIT

fail() {
  printf 'not ok - %s\n' "$*" >&2
  if [[ -n ${CASE_DIR:-} ]]; then
    printf 'calls:\n' >&2
    cat "$CASE_DIR/calls" >&2
    printf 'events:\n' >&2
    cat "$CASE_DIR/events" >&2
  fi
  exit 1
}

new_case() {
  CASE_DIR="$fixture_root/$1"
  mkdir -p "$CASE_DIR/bin" "$CASE_DIR/runtime" "$CASE_DIR/config/gtklock"
  export CASE_DIR XDG_RUNTIME_DIR="$CASE_DIR/runtime" XDG_CONFIG_HOME="$CASE_DIR/config" PATH="$CASE_DIR/bin:$PATH"
  : > "$CASE_DIR/calls"
  : > "$CASE_DIR/events"
  : > "$CASE_DIR/gtk-mode"
  : > "$CASE_DIR/sway-mode"
  : > "$CASE_DIR/systemctl-mode"
  : > "$CASE_DIR/dbus-mode"
  echo battery > "$CASE_DIR/ac-mode"
  echo battery > "$CASE_DIR/bus-mode"
  SUSPEND_MODE=idle
  ACQUIRE_ONLY=0
  cat > "$CASE_DIR/bin/lock-ack" <<'STUB'
#!/usr/bin/env bash
touch -- "$GNESHA_LOCK_ACK_FILE"
STUB
  cat > "$XDG_CONFIG_HOME/gtklock/config.ini" <<EOF
[main]
lock-command=$CASE_DIR/bin/lock-ack
EOF
  export SWAYSOCK="$CASE_DIR/sway-ipc.sock"
  : > "$SWAYSOCK"

  cat > "$CASE_DIR/bin/gtklock" <<'STUB'
#!/usr/bin/env bash
printf 'gtklock %s\n' "$*" >> "$CASE_DIR/calls"
printf 'gtk-start %s\n' "$(date +%s%N)" >> "$CASE_DIR/events"
case $(cat "$CASE_DIR/gtk-mode") in
  callback|callback-delayed)
    touch "$CASE_DIR/gtk-started"
    if [[ $(cat "$CASE_DIR/gtk-mode") == callback-delayed ]]; then
      while [[ ! -e $CASE_DIR/allow-gtk-ack ]]; do sleep 0.02; done
    fi
    # Gtklock reads its post-lock callback from lock-command in config.ini.
    # Support both its default XDG path and an explicitly selected config.
    config_path="${XDG_CONFIG_HOME:-$HOME/.config}/gtklock/config.ini"
    for ((i=1; i <= $#; i++)); do
      if [[ ${!i} == -c || ${!i} == --config ]]; then
        next=$((i + 1))
        config_path=${!next}
      fi
    done
    lock_command=$(awk -F= '$1 == "lock-command" { sub(/^[^=]*=/, ""); print; exit }' "$config_path")
    if [[ -n $lock_command ]]; then
      sleep "${READY_DELAY:-0.2}"
      printf 'gtklock-ready %s\n' "$(date +%s%N)" >> "$CASE_DIR/events"
      "$lock_command"
      sleep 30
    fi
    ;;
  timeout) sleep 30 ;;
  ignore-term) trap '' TERM; while :; do sleep 1; done ;;
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
        printf 'swaylock-ready %s\n' "$(date +%s%N)" >> "$CASE_DIR/events"
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
if [[ ${1:-} == suspend ]]; then
  printf 'suspend %s\n' "$(date +%s%N)" >> "$CASE_DIR/events"
  if flock -n -x "$XDG_RUNTIME_DIR/gnesha-lock/mutex" -c true; then
    printf 'suspend-mutex-missing\n' >> "$CASE_DIR/events"
  else
    printf 'suspend-mutex-held\n' >> "$CASE_DIR/events"
  fi
  if [[ -e $CASE_DIR/hold-systemctl-return ]]; then
    touch "$CASE_DIR/systemctl-entered"
    while [[ ! -e $CASE_DIR/release-systemctl ]]; do sleep 0.02; done
    printf 'suspend-return %s\n' "$(date +%s%N)" >> "$CASE_DIR/events"
  fi
  if [[ -e $CASE_DIR/before-sleep-callback ]]; then
    if timeout --kill-after=0.1s 0.5s bash -c 'source "$GNESHA_LOCK_HELPER"; gnesha_lock_acquire'; then
      printf 'before-sleep-returned\n' >> "$CASE_DIR/events"
    else
      printf 'before-sleep-blocked\n' >> "$CASE_DIR/events"
    fi
  fi
fi
STUB
  cat > "$CASE_DIR/bin/busctl" <<'STUB'
#!/usr/bin/env bash
printf 'busctl %s\n' "$*" >> "$CASE_DIR/calls"
case $(cat "$CASE_DIR/bus-mode") in
  battery) printf 'b false\n' ;;
  docked) printf 'b true\n' ;;
  malformed) printf 'false\n' ;;
  fail) exit 1 ;;
esac
STUB
  cat > "$CASE_DIR/bin/acpi" <<'STUB'
#!/usr/bin/env bash
case $(cat "$CASE_DIR/ac-mode") in
  battery) printf 'Adapter 0: off-line\n' ;;
  ac) printf 'Adapter 0: on-line\n' ;;
  fail) exit 1 ;;
esac
STUB
  cat > "$CASE_DIR/bin/dbus-send" <<'STUB'
#!/usr/bin/env bash
printf 'dbus-send %s\n' "$*" >> "$CASE_DIR/calls"
case $(cat "$CASE_DIR/dbus-mode") in
  delay) sleep 0.8 ;;
esac
STUB
  sed -i "1s|^#!/usr/bin/env bash$|#!$BASH|" "$CASE_DIR/bin/"*
  chmod +x "$CASE_DIR/bin/"*
}

run_lock_operation() {
  source "$helper"
  if [[ -n ${EXISTING_CHECK_DELAY:-} ]]; then
    eval "$(declare -f _gnesha_lock_existing | sed '1s/_gnesha_lock_existing/_fixture_original_existing/')"
    _gnesha_lock_existing() {
      sleep "$EXISTING_CHECK_DELAY"
      _fixture_original_existing "$@"
    }
  fi
  if declare -F gnesha_lock_and_suspend >/dev/null && [[ ${ACQUIRE_ONLY:-0} != 1 ]]; then
    if [[ ${SUSPEND_MODE:-idle} == lid ]]; then
      gnesha_lock_and_suspend --lid
    else
      gnesha_lock_and_suspend
    fi
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
  if source "$helper" && declare -F gnesha_lock_and_suspend >/dev/null; then
    grep -q '^suspend-mutex-held$' "$CASE_DIR/events" || fail 'suspend request did not hold the shared lock mutex'
    if grep -q '^suspend-mutex-missing$' "$CASE_DIR/events"; then fail 'shared lock mutex was not held during suspend'; fi
  fi
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
echo delay > "$CASE_DIR/dbus-mode"
operation_started=$(date +%s%N)
timed_lock_operation || fail 'swaylock readiness after gtklock timeout was rejected'
read -r gtk_started sway_started returned < <(awk '
  /^gtk-start / { gtk=$2 }
  /^sway-start / { sway=$2 }
  /^acquire-return / { returned=$2 }
  END { print gtk, sway, returned }
' "$CASE_DIR/events")
gtk_elapsed_ms=$(( (sway_started - gtk_started) / 1000000 ))
total_elapsed_ms=$(( (returned - gtk_started) / 1000000 ))
operation_elapsed_ms=$(( (returned - operation_started) / 1000000 ))
(( gtk_elapsed_ms <= 5500 )) || fail "gtklock attempt exceeded 5 seconds plus 500ms tolerance (${gtk_elapsed_ms}ms)"
(( total_elapsed_ms <= 10500 )) || fail "combined gtklock and swaylock attempt exceeded 10 seconds plus 500ms tolerance (${total_elapsed_ms}ms)"
(( operation_elapsed_ms <= 10500 )) || fail "full lock request exceeded 10 seconds plus 500ms tolerance (${operation_elapsed_ms}ms)"
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
ACQUIRE_ONLY=1
echo callback > "$CASE_DIR/gtk-mode"
echo fail > "$CASE_DIR/sway-mode"
( timed_lock_operation ) & first=$!
( timed_lock_operation ) & second=$!
wait "$first" || fail 'first concurrent lock request failed'
wait "$second" || fail 'second concurrent lock request failed'
assert_acquisition_after_readiness
if grep -q '^systemctl .*suspend' "$CASE_DIR/calls" || grep -q '^suspend ' "$CASE_DIR/events"; then fail 'lock-only concurrent request suspended'; fi
assert_call_count 1
printf 'ok - simultaneous requests launch only one locker\n'

new_case before-sleep-contention
echo callback > "$CASE_DIR/gtk-mode"
touch "$CASE_DIR/before-sleep-callback"
timed_lock_operation || fail 'battery suspend request failed'
grep -q '^before-sleep-returned$' "$CASE_DIR/events" || fail 'before-sleep lock callback blocked behind the suspend mutex'
assert_suspend_after_readiness
assert_call_count 1
printf 'ok - before-sleep reuses live acknowledged lock\n'

new_case callback-coalescing
echo callback-delayed > "$CASE_DIR/gtk-mode"
touch "$CASE_DIR/hold-systemctl-return"
(timed_lock_operation) & first_suspend=$!
for ((i=0; i<250; i++)); do
  [[ -e $CASE_DIR/gtk-started ]] && break
  sleep 0.02
done
[[ -e $CASE_DIR/gtk-started ]] || fail 'first suspend request did not start gtklock'
(
  source "$helper"
  gnesha_lock_acquire || exit 1
  printf 'coalesced-lock-return %s\n' "$(date +%s%N)" >> "$CASE_DIR/events"
) & second_lock=$!
sleep 0.15
if grep -q '^coalesced-lock-return ' "$CASE_DIR/events"; then
  touch "$CASE_DIR/release-systemctl"
  wait "$first_suspend" || true
  wait "$second_lock" || true
  fail 'second lock callback returned before any locker acknowledged readiness'
fi
touch "$CASE_DIR/allow-gtk-ack"
for ((i=0; i<250; i++)); do
  [[ -e $CASE_DIR/systemctl-entered ]] && break
  sleep 0.02
done
[[ -e $CASE_DIR/systemctl-entered ]] || {
  touch "$CASE_DIR/release-systemctl"
  wait "$first_suspend" || true
  wait "$second_lock" || true
  fail 'first suspend request did not reach systemctl'
}
for ((i=0; i<250; i++)); do
  [[ -n $(grep '^coalesced-lock-return ' "$CASE_DIR/events" || true) ]] && break
  sleep 0.02
done
if ! grep -q '^coalesced-lock-return ' "$CASE_DIR/events"; then
  touch "$CASE_DIR/release-systemctl"
  wait "$first_suspend" || true
  wait "$second_lock" || true
  fail 'second lock callback did not coalesce before suspend returned'
fi
assert_call_count 1
touch "$CASE_DIR/release-systemctl"
wait "$first_suspend" || fail 'first suspend request failed after coalescing'
wait "$second_lock" || fail 'second lock callback failed after coalescing'
[[ $(grep -c '^coalesced-lock-return ' "$CASE_DIR/events") == 1 ]] || fail 'second callback did not return exactly once'
[[ $(grep -c '^suspend-return ' "$CASE_DIR/events") == 1 ]] || fail 'suspend stub did not return exactly once'
coalesced_return=$(awk '/^coalesced-lock-return / { print $2 }' "$CASE_DIR/events")
suspend_return=$(awk '/^suspend-return / { print $2 }' "$CASE_DIR/events")
(( coalesced_return < suspend_return )) || fail 'second lock callback returned after systemctl suspend returned'
printf 'ok - in-progress locker acknowledgment coalesces lock callback\n'

new_case stale-state-contention
ACQUIRE_ONLY=1
echo callback > "$CASE_DIR/gtk-mode"
mkdir -p "$XDG_RUNTIME_DIR/gnesha-lock"
printf 'gtklock 99999999 1\n' > "$XDG_RUNTIME_DIR/gnesha-lock/state"
(
  exec 9>"$XDG_RUNTIME_DIR/gnesha-lock/mutex"
  flock -x 9
  touch "$CASE_DIR/held"
  sleep 0.8
) & holder=$!
for ((i=0; i<100; i++)); do
  [[ -e $CASE_DIR/held ]] && break
  sleep 0.01
done
[[ -e $CASE_DIR/held ]] || fail 'fixture could not hold the mutex for stale-state test'
(timed_lock_operation) & operation=$!
sleep 0.2
assert_call_count 0
if grep -q '^acquire-return ' "$CASE_DIR/events"; then fail 'stale state bypassed the mutex'; fi
wait "$holder" || fail 'stale-state mutex holder failed'
wait "$operation" || fail 'stale-state request failed after mutex release'
assert_call_count 1
assert_acquisition_after_readiness
printf 'ok - stale acknowledgment remains serialized\n'

new_case contention
echo callback > "$CASE_DIR/gtk-mode"
mkdir -p "$XDG_RUNTIME_DIR/gnesha-lock"
(
  exec 9>"$XDG_RUNTIME_DIR/gnesha-lock/mutex"
  flock -x 9
  touch "$CASE_DIR/held"
  sleep 12
) & holder=$!
for ((i=0; i<100; i++)); do
  [[ -e $CASE_DIR/held ]] && break
  sleep 0.01
done
[[ -e $CASE_DIR/held ]] || fail 'fixture could not establish lock contention'
operation_started=$(date +%s%N)
if timed_lock_operation; then fail 'contended lock unexpectedly succeeded'; fi
operation_ended=$(date +%s%N)
operation_elapsed_ms=$(( (operation_ended - operation_started) / 1000000 ))
(( operation_elapsed_ms <= 10500 )) || fail "contended request exceeded 10 seconds plus 500ms tolerance (${operation_elapsed_ms}ms)"
assert_call_count 0
kill "$holder" 2>/dev/null || true
wait "$holder" 2>/dev/null || true
printf 'ok - lock contention is bounded\n'

new_case stubborn-gtklock
echo ignore-term > "$CASE_DIR/gtk-mode"
echo ready > "$CASE_DIR/sway-mode"
operation_started=$(date +%s%N)
timed_lock_operation || fail 'SIGTERM-ignoring gtklock prevented fallback'
operation_ended=$(date +%s%N)
operation_elapsed_ms=$(( (operation_ended - operation_started) / 1000000 ))
(( operation_elapsed_ms <= 10500 )) || fail "stubborn gtklock request exceeded 10 seconds plus 500ms tolerance (${operation_elapsed_ms}ms)"
assert_acquisition_after_readiness
assert_call_count 2
printf 'ok - stubborn gtklock cleanup is bounded\n'

hold_mutex() {
  local duration=$1
  mkdir -p "$XDG_RUNTIME_DIR/gnesha-lock"
  (
    exec 9>"$XDG_RUNTIME_DIR/gnesha-lock/mutex"
    flock -x 9
    touch "$CASE_DIR/held"
    sleep "$duration"
  ) & holder=$!
  for ((i=0; i<100; i++)); do
    [[ -e $CASE_DIR/held ]] && break
    sleep 0.01
  done
  [[ -e $CASE_DIR/held ]] || fail 'fixture could not establish near-deadline contention'
}

new_case near-deadline-existing
echo callback > "$CASE_DIR/gtk-mode"
export GNESHA_LOCK_ACK_FILE="$CASE_DIR/preexisting-ack"
"$CASE_DIR/bin/gtklock" & existing_locker=$!
for ((i=0; i<100; i++)); do
  [[ -e $GNESHA_LOCK_ACK_FILE ]] && break
  sleep 0.01
done
[[ -e $GNESHA_LOCK_ACK_FILE ]] || fail 'fixture could not establish an acknowledged locker'
mkdir -p "$XDG_RUNTIME_DIR/gnesha-lock"
existing_start=$(awk '{ print $22 }' "/proc/$existing_locker/stat")
printf 'gtklock %s %s\n' "$existing_locker" "$existing_start" > "$XDG_RUNTIME_DIR/gnesha-lock/state"
hold_mutex 9.6
operation_started=$(date +%s%N)
timed_lock_operation || fail 'existing acknowledged locker was rejected near the deadline'
operation_ended=$(date +%s%N)
operation_elapsed_ms=$(( (operation_ended - operation_started) / 1000000 ))
(( operation_elapsed_ms <= 10500 )) || fail "existing locker request returned late (${operation_elapsed_ms}ms)"
assert_call_count 1
rm -f "$CASE_DIR/held"
hold_mutex 9.45
export EXISTING_CHECK_DELAY=0.65
operation_started=$(date +%s%N)
if timed_lock_operation; then fail 'existing locker succeeded after its deadline'; fi
operation_ended=$(date +%s%N)
operation_elapsed_ms=$(( (operation_ended - operation_started) / 1000000 ))
(( operation_elapsed_ms <= 10500 )) || fail "late existing locker request exceeded timing tolerance (${operation_elapsed_ms}ms)"
assert_call_count 1
unset EXISTING_CHECK_DELAY
kill "$existing_locker" 2>/dev/null || true
kill "$holder" 2>/dev/null || true
wait "$holder" 2>/dev/null || true
printf 'ok - existing acknowledgment returns within deadline\n'

new_case near-deadline-new
echo callback > "$CASE_DIR/gtk-mode"
hold_mutex 9.3
operation_started=$(date +%s%N)
if timed_lock_operation; then fail 'new locker succeeded after near-deadline contention'; fi
operation_ended=$(date +%s%N)
operation_elapsed_ms=$(( (operation_ended - operation_started) / 1000000 ))
(( operation_elapsed_ms <= 10500 )) || fail "new locker request returned late (${operation_elapsed_ms}ms)"
assert_call_count 0
[[ ! -s $CASE_DIR/calls ]] || fail 'ancillary command ran without enough time for locking'
kill "$holder" 2>/dev/null || true
wait "$holder" 2>/dev/null || true
printf 'ok - new locker does not start near deadline\n'

new_case battery-lid
SUSPEND_MODE=lid
echo callback > "$CASE_DIR/gtk-mode"
echo battery > "$CASE_DIR/bus-mode"
echo battery > "$CASE_DIR/ac-mode"
timed_lock_operation || fail 'battery lid request did not lock then suspend'
assert_acquisition_after_readiness
assert_suspend_after_readiness
[[ $(grep -c '^busctl ' "$CASE_DIR/calls") == 1 ]] || fail 'battery lid request did not query logind Docked state'
printf 'ok - battery lid request suspends after readiness\n'

new_case ac-lid
SUSPEND_MODE=lid
echo callback > "$CASE_DIR/gtk-mode"
echo battery > "$CASE_DIR/bus-mode"
echo ac > "$CASE_DIR/ac-mode"
timed_lock_operation || fail 'AC lid request did not lock successfully'
assert_acquisition_after_readiness
if grep -q '^systemctl .*suspend' "$CASE_DIR/calls" || grep -q '^suspend ' "$CASE_DIR/events"; then fail 'AC lid request suspended'; fi
printf 'ok - AC lid request locks without suspending\n'

new_case docked-lid
SUSPEND_MODE=lid
echo callback > "$CASE_DIR/gtk-mode"
echo docked > "$CASE_DIR/bus-mode"
timed_lock_operation || fail 'docked lid request did not lock successfully'
assert_acquisition_after_readiness
if grep -q '^systemctl .*suspend' "$CASE_DIR/calls" || grep -q '^suspend ' "$CASE_DIR/events"; then fail 'docked lid request suspended'; fi
printf 'ok - docked lid request locks without suspending\n'

new_case dock-query-failure
SUSPEND_MODE=lid
echo callback > "$CASE_DIR/gtk-mode"
echo fail > "$CASE_DIR/bus-mode"
if timed_lock_operation; then fail 'Docked query failure was not reported'; fi
assert_acquisition_after_readiness
if grep -q '^systemctl .*suspend' "$CASE_DIR/calls" || grep -q '^suspend ' "$CASE_DIR/events"; then fail 'Docked query failure allowed suspend'; fi
printf 'ok - failed Docked query leaves system awake\n'

new_case dock-query-malformed
SUSPEND_MODE=lid
echo callback > "$CASE_DIR/gtk-mode"
echo malformed > "$CASE_DIR/bus-mode"
if timed_lock_operation; then fail 'malformed Docked property was not rejected'; fi
assert_acquisition_after_readiness
if grep -q '^systemctl .*suspend' "$CASE_DIR/calls" || grep -q '^suspend ' "$CASE_DIR/events"; then fail 'malformed Docked property allowed suspend'; fi
printf 'ok - malformed Docked property leaves system awake\n'

new_case ac-query-failure
SUSPEND_MODE=idle
echo callback > "$CASE_DIR/gtk-mode"
echo fail > "$CASE_DIR/ac-mode"
if timed_lock_operation; then fail 'AC state query failure was not reported'; fi
assert_acquisition_after_readiness
if grep -q '^systemctl .*suspend' "$CASE_DIR/calls" || grep -q '^suspend ' "$CASE_DIR/events"; then fail 'AC state query failure allowed suspend'; fi
printf 'ok - failed AC query leaves system awake\n'

new_case battery-idle
SUSPEND_MODE=idle
echo callback > "$CASE_DIR/gtk-mode"
echo battery > "$CASE_DIR/ac-mode"
timed_lock_operation || fail 'battery idle request did not lock then suspend'
assert_acquisition_after_readiness
assert_suspend_after_readiness
printf 'ok - battery idle request suspends after readiness\n'

new_case readiness-failure-suspend
SUSPEND_MODE=lid
echo fail > "$CASE_DIR/gtk-mode"
echo fail > "$CASE_DIR/sway-mode"
echo battery > "$CASE_DIR/bus-mode"
if timed_lock_operation; then fail 'suspend request succeeded without lock readiness'; fi
if grep -q '^systemctl .*suspend' "$CASE_DIR/calls" || grep -q '^suspend ' "$CASE_DIR/events"; then fail 'readiness failure allowed suspend'; fi
printf 'ok - lock readiness failure leaves system awake\n'
