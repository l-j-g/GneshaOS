# Review a prepared update without waiting for its build lock or changing files.
update_review() {
  local state="$1" repo="$2" current_system="$3" ready
  exec 8>"$state/lock"
  if ! flock -n 8; then
    echo "The background update build is still running; review is nonblocking. Retry update-review after it completes. Use update-status for current service state."
    exec 8>&-
    return 0
  fi
  if [ ! -L "$state/ready" ]; then
    echo "No completed update is ready. Check systemctl status gnesha-nixpkgs-update." >&2
    flock -u 8
    exec 8>&-
    return 1
  fi
  ready=$(readlink -f "$state/ready")
  echo "Candidate built at $(cat "$ready/built-at")"
  diff -u "$repo/flake.lock" "$ready/source/flake.lock" || [ "$?" -eq 1 ]
  nvd diff "$current_system" "$ready/system"
  flock -u 8
  exec 8>&-
}
