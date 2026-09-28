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

gnesha_lock_acquire() (
  local state_dir seconds overall_deadline left status
  overall_deadline=$(( $(date +%s%N) + 10000000000 ))
  [[ -n ${SWAYSOCK:-} && -n ${XDG_RUNTIME_DIR:-} ]] || return 1
  state_dir=$XDG_RUNTIME_DIR/gnesha-lock
  mkdir -p -- "$state_dir" || return 1
  chmod 700 -- "$state_dir" || return 1
  exec 9>"$state_dir/mutex"
  left=$(_gnesha_lock_seconds_left "$overall_deadline") || return 1
  flock -x -w "$left" 9 || return 1
  if _gnesha_lock_existing "$state_dir"; then
    flock -u 9
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
    flock -u 9
    _gnesha_lock_seconds_left "$overall_deadline" >/dev/null
    return $?
  else
    status=$?
  fi
  (( status == 2 )) && return 1
  left=$(_gnesha_lock_seconds_left "$((overall_deadline - 900000000))") || return 1
  if _gnesha_lock_attempt_sway "$state_dir" "$seconds" "$overall_deadline"; then
    flock -u 9
    _gnesha_lock_seconds_left "$overall_deadline" >/dev/null
    return $?
  fi
  flock -u 9
  return 1
)
