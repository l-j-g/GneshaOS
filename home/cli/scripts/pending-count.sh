# Count package version changes that the next rebuild would apply.
#
# Rebuild activates the closures that flake.lock already resolves to. The
# gnesha-lock-refresh timer advances that lock and downloads the resulting
# closures without activating them, so these helpers compare the running
# system against the refreshed lock to report what rebuild would change.
#
# nvd takes a few seconds over two full closures, so the refresh job caches
# its result and callers read that cache instead of recomputing.

GNESHA_UPDATE_STATE=${GNESHA_UPDATE_STATE:-$HOME/.local/state/gnesha-lock-refresh}

# Resolve the refreshed closure directory, or return 1 when nothing is cached.
pending_ready() {
  # shellcheck disable=SC3043 # dash supports local
  local ready
  [ -d "$GNESHA_UPDATE_STATE" ] || return 1
  ready=$(readlink -f "$GNESHA_UPDATE_STATE/refreshed" 2>/dev/null) || return 1
  [ -d "$ready" ] || return 1
  printf '%s\n' "$ready"
}

# Print "system home" version-change counts for the pending rebuild, or return
# 1 when no refresh has completed yet.
pending_count() {
  # shellcheck disable=SC3043 # dash supports local
  local ready
  ready=$(pending_ready) || return 1
  [ -r "$ready/count" ] || return 1
  cat "$ready/count"
}

# Print the refreshed system closure path, or return 1 when nothing is cached.
pending_system_path() {
  # shellcheck disable=SC3043 # dash supports local
  local ready
  ready=$(pending_ready) || return 1
  [ -r "$ready/system-path" ] || return 1
  cat "$ready/system-path"
}

# Print the refreshed Home Manager closure path, or return 1 when absent.
pending_home_path() {
  # shellcheck disable=SC3043 # dash supports local
  local ready
  ready=$(pending_ready) || return 1
  [ -r "$ready/home-path" ] || return 1
  cat "$ready/home-path"
}

# Print the refresh build time as "YYYY-MM-DD HH:MM", or nothing when absent.
pending_built_at() {
  # shellcheck disable=SC3043 # dash supports local
  local ready
  ready=$(pending_ready) || return 1
  [ -r "$ready/built-at" ] || return 1
  cut -c1-16 "$ready/built-at"
}

# Print whole days since the last successful refresh. A refresh older than a
# day means the lock has not advanced recently.
pending_age_days() {
  # shellcheck disable=SC3043 # dash supports local
  local ready built now
  ready=$(pending_ready) || return 1
  built=$(date -d "$(cat "$ready/built-at")" +%s 2>/dev/null) || return 1
  now=$(date +%s)
  printf '%s\n' "$(( (now - built) / 86400 ))"
}