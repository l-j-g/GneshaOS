#!/usr/bin/env bash
# Source this file to acquire a lock with a positive compositor acknowledgment.

_gnesha_lock_identity() {
  local stat rest state
  local -a fields
  [[ -r /proc/$1/stat ]] || return 1
  IFS= read -r stat < "/proc/$1/stat" || return 1
  rest=${stat##*) }
  read -r -a fields <<< "$rest"
  state=${fields[0]}
  [[ $state != Z && $state != X ]] || return 1
  printf '%s\n' "${fields[19]}"
}

_gnesha_lock_existing() {
  local kind pid start current
  [[ -r $1/state ]] || return 1
  read -r kind pid start < "$1/state" || return 1
  [[ $kind == gtklock || $kind == swaylock ]] || return 1
  [[ $pid =~ ^[0-9]+$ && $start =~ ^[0-9]+$ ]] || return 1
  current=$(_gnesha_lock_identity "$pid") || return 1
  [[ $current == "$start" ]]
}

_gnesha_lock_stop() {
  local pid=$1 i
  if ! kill "$pid" 2>/dev/null; then
    _gnesha_lock_identity "$pid" >/dev/null 2>&1 && return 1
    return 0
  fi
  for ((i = 0; i < 3; i++)); do
    _gnesha_lock_identity "$pid" >/dev/null 2>&1 || return 0
    sleep 0.05
  done
  if ! kill -KILL "$pid" 2>/dev/null; then
    _gnesha_lock_identity "$pid" >/dev/null 2>&1 && return 1
    return 0
  fi
  for ((i = 0; i < 3; i++)); do
    _gnesha_lock_identity "$pid" >/dev/null 2>&1 || return 0
    sleep 0.05
  done
  return 1
}

_gnesha_lock_seconds_left() {
  local left=$(( $1 - $(date +%s%N) ))
  (( left > 0 )) || return 1
  printf '%d.%09d\n' "$((left / 1000000000))" "$((left % 1000000000))"
}

_gnesha_lock_attempt_gtk() {
  local state_dir=$1 seconds=$2 overall_deadline=$3 attempt_dir pid start deadline now
  attempt_dir=$(mktemp -d "$state_dir/attempt.XXXXXXXX") || return 1
  export GNESHA_LOCK_ACK_FILE="$attempt_dir/ack"
  gtklock &
  pid=$!
  start=$(_gnesha_lock_identity "$pid") || {
    if ! _gnesha_lock_stop "$pid"; then
      rm -rf -- "$attempt_dir"
      return 2
    fi
    rm -rf -- "$attempt_dir"
    return 1
  }
  now=$(date +%s%N)
  deadline=$(( now + seconds * 1000000000 ))
  (( deadline > overall_deadline - 400000000 )) && deadline=$(( overall_deadline - 400000000 ))
  while (( $(date +%s%N) < deadline )); do
    if [[ -f $GNESHA_LOCK_ACK_FILE ]] &&
      [[ $(_gnesha_lock_identity "$pid" 2>/dev/null) == "$start" ]] &&
      (( $(date +%s%N) < deadline )); then
      printf 'gtklock %s %s\n' "$pid" "$start" > "$state_dir/state"
      rm -rf -- "$attempt_dir"
      return 0
    fi
    if ! kill -0 "$pid" 2>/dev/null; then break; fi
    sleep 0.05
  done
  if ! _gnesha_lock_stop "$pid"; then
    rm -rf -- "$attempt_dir"
    return 2
  fi
  rm -rf -- "$attempt_dir"
  return 1
}

_gnesha_lock_attempt_sway() {
  local state_dir=$1 seconds=$2 overall_deadline=$3 attempt_dir pid start ready deadline now left
  attempt_dir=$(mktemp -d "$state_dir/attempt.XXXXXXXX") || return 1
  mkfifo "$attempt_dir/ready" || {
    rm -rf -- "$attempt_dir"
    return 1
  }
  if ! exec 8<>"$attempt_dir/ready"; then
    rm -rf -- "$attempt_dir"
    return 1
  fi
  swaylock --ready-fd 8 &
  pid=$!
  start=$(_gnesha_lock_identity "$pid") || {
    if ! _gnesha_lock_stop "$pid"; then
      exec 8>&-
      rm -rf -- "$attempt_dir"
      return 2
    fi
    exec 8>&-
    rm -rf -- "$attempt_dir"
    return 1
  }
  now=$(date +%s%N)
  deadline=$(( now + seconds * 1000000000 ))
  (( deadline > overall_deadline - 400000000 )) && deadline=$(( overall_deadline - 400000000 ))
  left=$(_gnesha_lock_seconds_left "$deadline") || left=0
  if IFS= read -r -t "$left" ready <&8 &&
    [[ -z $ready ]] &&
    [[ $(_gnesha_lock_identity "$pid" 2>/dev/null) == "$start" ]] &&
    (( $(date +%s%N) < deadline )); then
    printf 'swaylock %s %s\n' "$pid" "$start" > "$state_dir/state"
    exec 8>&-
    rm -rf -- "$attempt_dir"
    return 0
  fi
  if ! _gnesha_lock_stop "$pid"; then
    exec 8>&-
    rm -rf -- "$attempt_dir"
    return 2
  fi
  exec 8>&-
  rm -rf -- "$attempt_dir"
  return 1
}

_gnesha_lock_acquire_locked() {
  local state_dir=$1 overall_deadline=$2
  local seconds left status
  if _gnesha_lock_existing "$state_dir"; then
    _gnesha_lock_seconds_left "$overall_deadline" >/dev/null
    return $?
  fi
  rm -f -- "$state_dir/state"
  seconds=${GNESHA_LOCK_TIMEOUT_SECONDS:-5}
  [[ $seconds =~ ^[1-5]$ ]] || seconds=5
  # Preserve the existing best-effort KeePassXC vault lock.
  left=$(_gnesha_lock_seconds_left "$((overall_deadline - 1800000000))") || return 1
  timeout --kill-after=0.1s 0.8s dbus-send --session --print-reply --reply-timeout=800 \
    --dest=org.keepassxc.KeePassXC.MainWindow /keepassxc \
    org.keepassxc.KeePassXC.MainWindow.lockAllDatabases >/dev/null 2>&1 || true
  left=$(_gnesha_lock_seconds_left "$((overall_deadline - 900000000))") || return 1
  if _gnesha_lock_attempt_gtk "$state_dir" "$seconds" "$overall_deadline"; then
    _gnesha_lock_seconds_left "$overall_deadline" >/dev/null
    return $?
  else
    status=$?
  fi
  (( status == 2 )) && return 1
  left=$(_gnesha_lock_seconds_left "$((overall_deadline - 900000000))") || return 1
  if _gnesha_lock_attempt_sway "$state_dir" "$seconds" "$overall_deadline"; then
    _gnesha_lock_seconds_left "$overall_deadline" >/dev/null
    return $?
  fi
  return 1
}

_gnesha_lock_take_mutex() {
  local runtime_dir=$1 deadline=$2 left
  [[ -n ${SWAYSOCK:-} && -n $runtime_dir ]] || {
    printf 'gnesha-lock: Sway session or XDG_RUNTIME_DIR is unavailable\n' >&2
    return 1
  }
  mkdir -p -- "$runtime_dir/gnesha-lock" || return 1
  chmod 700 -- "$runtime_dir/gnesha-lock" || return 1
  exec 9>"$runtime_dir/gnesha-lock/mutex"
  left=$(_gnesha_lock_seconds_left "$deadline") || return 1
  flock -x -w "$left" 9 || {
    printf 'gnesha-lock: timed out waiting for another lock request\n' >&2
    return 1
  }
}

_gnesha_lock_take_mutex_or_reuse() {
  local runtime_dir=$1 deadline=$2 state_dir left
  [[ -n ${SWAYSOCK:-} && -n $runtime_dir ]] || {
    printf 'gnesha-lock: Sway session or XDG_RUNTIME_DIR is unavailable\n' >&2
    return 1
  }
  state_dir=$runtime_dir/gnesha-lock
  mkdir -p -- "$state_dir" || return 1
  chmod 700 -- "$state_dir" || return 1
  exec 9>"$state_dir/mutex"
  while :; do
    if _gnesha_lock_existing "$state_dir"; then
      _gnesha_lock_seconds_left "$deadline" >/dev/null || return 1
      return 10
    fi
    left=$(_gnesha_lock_seconds_left "$deadline") || {
      printf 'gnesha-lock: timed out waiting for another lock request\n' >&2
      return 1
    }
    if flock -n -x 9; then
      return 0
    fi
    sleep 0.05
  done
}

gnesha_lock_acquire() (
  local state_dir overall_deadline status
  overall_deadline=$(( $(date +%s%N) + 10000000000 ))
  [[ -n ${SWAYSOCK:-} && -n ${XDG_RUNTIME_DIR:-} ]] || {
    printf 'gnesha-lock: Sway session or XDG_RUNTIME_DIR is unavailable\n' >&2
    return 1
  }
  state_dir=$XDG_RUNTIME_DIR/gnesha-lock
  # before-sleep can run while gnesha-lock-and-suspend holds the mutex. A
  # positively acknowledged, still-live locker needs no new acquisition.
  if _gnesha_lock_existing "$state_dir"; then
    _gnesha_lock_seconds_left "$overall_deadline" >/dev/null
    return $?
  fi
  if _gnesha_lock_take_mutex_or_reuse "$XDG_RUNTIME_DIR" "$overall_deadline"; then
    :
  else
    status=$?
    (( status == 10 )) && return 0
    return "$status"
  fi
  if _gnesha_lock_acquire_locked "$state_dir" "$overall_deadline"; then
    status=0
  else
    status=$?
  fi
  # Locker children inherit the flock descriptor; release it explicitly once
  # the verified lock is established so later callers can reuse that state.
  flock -u 9 || true
  return "$status"
)

_gnesha_lock_suspend_locked() {
  local mode=$1 state_dir=$2 overall_deadline=$3 docked power_status
  _gnesha_lock_acquire_locked "$state_dir" "$overall_deadline" || {
    printf 'gnesha-lock-and-suspend: lock readiness failed; leaving the machine awake\n' >&2
    return 1
  }
  if [[ $mode == lid ]]; then
    docked=$(timeout --kill-after=0.2s 2s busctl get-property \
      org.freedesktop.login1 /org/freedesktop/login1 \
      org.freedesktop.login1.Manager Docked 2>/dev/null) || {
      printf 'gnesha-lock-and-suspend: unable to read logind Docked state; leaving the machine awake\n' >&2
      return 1
    }
    case $docked in
      'b true') return 0 ;;
      'b false') ;;
      *)
        printf 'gnesha-lock-and-suspend: unexpected logind Docked value %q; leaving the machine awake\n' "$docked" >&2
        return 1
        ;;
    esac
  fi
  power_status=$(timeout --kill-after=0.2s 2s acpi --ac-adapter 2>/dev/null) || {
    printf 'gnesha-lock-and-suspend: unable to read AC power state; leaving the machine awake\n' >&2
    return 1
  }
  if [[ $power_status == *'on-line'* ]]; then
    return 0
  fi
  if [[ $power_status != *'off-line'* ]]; then
    printf 'gnesha-lock-and-suspend: unexpected AC power state; leaving the machine awake\n' >&2
    return 1
  fi
  _gnesha_lock_existing "$state_dir" || {
    printf 'gnesha-lock-and-suspend: locker exited before suspend; leaving the machine awake\n' >&2
    return 1
  }
  systemctl suspend
}

gnesha_lock_and_suspend() (
  local mode=idle state_dir overall_deadline status
  if [[ $# -gt 1 || ( $# -eq 1 && $1 != --lid ) ]]; then
    printf 'usage: gnesha-lock-and-suspend [--lid]\n' >&2
    return 2
  fi
  [[ $# -eq 0 ]] || mode=lid
  overall_deadline=$(( $(date +%s%N) + 10000000000 ))
  _gnesha_lock_take_mutex "${XDG_RUNTIME_DIR:-}" "$overall_deadline" || return 1
  state_dir=$XDG_RUNTIME_DIR/gnesha-lock
  if _gnesha_lock_suspend_locked "$mode" "$state_dir" "$overall_deadline"; then
    status=0
  else
    status=$?
  fi
  # Keep the mutex through the suspend request, but not in the locker child.
  flock -u 9 || true
  return "$status"
)
