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
  kill "$1" 2>/dev/null || true
  wait "$1" 2>/dev/null || true
}

_gnesha_lock_attempt_gtk() {
  local state_dir=$1 seconds=$2 attempt_dir pid start deadline
  attempt_dir=$(mktemp -d "$state_dir/attempt.XXXXXXXX") || return 1
  export GNESHA_LOCK_ACK_FILE="$attempt_dir/ack"
  gtklock &
  pid=$!
  start=$(_gnesha_lock_identity "$pid") || {
    _gnesha_lock_stop "$pid"
    rm -rf -- "$attempt_dir"
    return 1
  }
  deadline=$(( $(date +%s%N) + seconds * 1000000000 ))
  while (( $(date +%s%N) < deadline )); do
    if [[ -f $GNESHA_LOCK_ACK_FILE ]] &&
      [[ $(_gnesha_lock_identity "$pid" 2>/dev/null) == "$start" ]]; then
      printf 'gtklock %s %s\n' "$pid" "$start" > "$state_dir/state"
      rm -rf -- "$attempt_dir"
      return 0
    fi
    if ! kill -0 "$pid" 2>/dev/null; then break; fi
    sleep 0.05
  done
  _gnesha_lock_stop "$pid"
  rm -rf -- "$attempt_dir"
  return 1
}

_gnesha_lock_attempt_sway() {
  local state_dir=$1 seconds=$2 attempt_dir pid start ready
  attempt_dir=$(mktemp -d "$state_dir/attempt.XXXXXXXX") || return 1
  mkfifo "$attempt_dir/ready" || return 1
  exec 8<>"$attempt_dir/ready"
  swaylock --ready-fd 8 &
  pid=$!
  start=$(_gnesha_lock_identity "$pid") || {
    _gnesha_lock_stop "$pid"
    exec 8>&-
    rm -rf -- "$attempt_dir"
    return 1
  }
  if IFS= read -r -t "$seconds" ready <&8 &&
    [[ -z $ready ]] &&
    [[ $(_gnesha_lock_identity "$pid" 2>/dev/null) == "$start" ]]; then
    printf 'swaylock %s %s\n' "$pid" "$start" > "$state_dir/state"
    exec 8>&-
    rm -rf -- "$attempt_dir"
    return 0
  fi
  _gnesha_lock_stop "$pid"
  exec 8>&-
  rm -rf -- "$attempt_dir"
  return 1
}

gnesha_lock_acquire() (
  local state_dir seconds
  [[ -n ${SWAYSOCK:-} && -n ${XDG_RUNTIME_DIR:-} ]] || return 1
  state_dir=$XDG_RUNTIME_DIR/gnesha-lock
  mkdir -p -- "$state_dir" || return 1
  chmod 700 -- "$state_dir" || return 1
  exec 9>"$state_dir/mutex"
  flock -x 9 || return 1
  if _gnesha_lock_existing "$state_dir"; then
    flock -u 9
    return 0
  fi
  rm -f -- "$state_dir/state"
  seconds=${GNESHA_LOCK_TIMEOUT_SECONDS:-5}
  [[ $seconds =~ ^[1-5]$ ]] || seconds=5
  # Preserve the existing best-effort KeePassXC vault lock.
  dbus-send --session --print-reply --reply-timeout=1000 \
    --dest=org.keepassxc.KeePassXC.MainWindow /keepassxc \
    org.keepassxc.KeePassXC.MainWindow.lockAllDatabases >/dev/null 2>&1 || true
  if _gnesha_lock_attempt_gtk "$state_dir" "$seconds" ||
    _gnesha_lock_attempt_sway "$state_dir" "$seconds"; then
    flock -u 9
    return 0
  fi
  flock -u 9
  return 1
)
