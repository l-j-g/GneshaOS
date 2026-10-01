# Shared helpers for the prepared-update candidate in $GNESHA_UPDATE_STATE.
#
# The candidate is built by the gnesha-nixpkgs-update system timer, which never
# activates it. These helpers summarise what activating it would change, so the
# number can be cached once at build time instead of recomputed on every poll.

GNESHA_UPDATE_STATE=${GNESHA_UPDATE_STATE:-/var/lib/gnesha-update}

# Resolve the candidate directory, or return 1 when nothing has been prepared.
pending_ready() {
  local ready
  ready=$(readlink -f "$GNESHA_UPDATE_STATE/ready" 2>/dev/null) || return 1
  [ -d "$ready" ] || return 1
  printf '%s\n' "$ready"
}

# Print the number of packages whose version differs between the running system
# and the prepared candidate. Counts both the system and Home Manager closures.
# Runs nvd, which takes a few seconds, so callers should cache the result.
pending_count() {
  local ready count
  ready=$(pending_ready) || return 1
  count=$({
    nvd diff /run/current-system "$ready/system" 2>/dev/null
    nvd diff "$HOME/.local/state/nix/profiles/home-manager" "$ready/home" 2>/dev/null
  } | grep -cE '^\[U') || count=0
  printf '%s\n' "$count"
}

# Print the candidate build time as "YYYY-MM-DD HH:MM", or nothing when absent.
pending_built_at() {
  local ready
  ready=$(pending_ready) || return 1
  [ -r "$ready/built-at" ] || return 1
  cut -c1-16 "$ready/built-at"
}

# Print the age of the candidate in whole days. Updates are stale once a day
# has passed without a successful build.
pending_age_days() {
  local ready built now
  ready=$(pending_ready) || return 1
  built=$(date -d "$(cat "$ready/built-at")" +%s 2>/dev/null) || return 1
  now=$(date +%s)
  printf '%s\n' "$(( (now - built) / 86400 ))"
}