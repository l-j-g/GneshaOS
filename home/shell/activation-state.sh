#!/usr/bin/env bash
# Shared state and lock helpers for system and Home Manager activations.
# Callers set activation_state_root before sourcing this file if needed.

activation_state_root="${activation_state_root:-${GNESHA_ACTIVATION_STATE_ROOT:-$HOME/.local/state/gnesha-activation}}"
activation_transactions="$activation_state_root/transactions"
activation_lock_file="$activation_state_root/activation.lock"

activation_init() {
  umask 077
  mkdir -p -- "$activation_transactions"
  chmod 700 -- "$activation_state_root" "$activation_transactions"
}

activation_lock() {
  activation_init
  exec 9>"$activation_lock_file"
  chmod 600 -- "$activation_lock_file"
  flock -x 9
}

activation_unlock() {
  flock -u 9
  exec 9>&-
}

activation_id_valid() {
  [[ "$1" =~ ^(rebuild|update)-[A-Za-z0-9_-]+$ ]]
}

activation_state_save() {
  local temporary="$activation_dir/state.tmp.$$"
  {
    printf 'version=1\n'
    printf 'id=%s\n' "$activation_id"
    printf 'kind=%s\n' "$activation_kind"
    printf 'phase=%s\n' "$activation_phase"
    printf 'snapshot=%s\n' "$activation_snapshot"
    printf 'old_system=%s\n' "$activation_old_system"
    printf 'old_home=%s\n' "$activation_old_home"
    printf 'new_system=%s\n' "$activation_new_system"
    printf 'new_home=%s\n' "$activation_new_home"
    printf 'repo=%s\n' "$activation_repo"
    printf 'old_lock=%s\n' "$activation_old_lock"
    printf 'new_lock=%s\n' "$activation_new_lock"
  } > "$temporary"
  chmod 600 -- "$temporary"
  mv -f -- "$temporary" "$activation_dir/state"
}

activation_state_load() {
  activation_id="$1"
  activation_id_valid "$activation_id" || {
    printf 'Invalid activation id: %s\n' "$activation_id" >&2
    return 2
  }
  activation_dir="$activation_transactions/$activation_id"
  [[ -d "$activation_dir" && ! -L "$activation_dir" && -r "$activation_dir/state" ]] || {
    printf 'Activation state not found: %s\n' "$activation_id" >&2
    return 1
  }

  activation_kind=
  activation_phase=
  activation_snapshot=
  activation_old_system=
  activation_old_home=
  activation_new_system=
  activation_new_home=
  activation_repo=
  activation_old_lock=
  activation_new_lock=
  local key value
  while IFS='=' read -r key value; do
    case "$key" in
      version) [[ "$value" == 1 ]] || return 1 ;;
      id) [[ "$value" == "$activation_id" ]] || return 1 ;;
      kind) activation_kind="$value" ;;
      phase) activation_phase="$value" ;;
      snapshot) activation_snapshot="$value" ;;
      old_system) activation_old_system="$value" ;;
      old_home) activation_old_home="$value" ;;
      new_system) activation_new_system="$value" ;;
      new_home) activation_new_home="$value" ;;
      repo) activation_repo="$value" ;;
      old_lock) activation_old_lock="$value" ;;
      new_lock) activation_new_lock="$value" ;;
    esac
  done < "$activation_dir/state"

  [[ "$activation_kind" == rebuild || "$activation_kind" == update ]] || return 1
  [[ -n "$activation_phase" && -n "$activation_snapshot" ]] || return 1
}

activation_create() {
  activation_init
  activation_kind="$1"
  activation_snapshot="$2"
  activation_repo="${3:-}"
  activation_id="$activation_kind-$(date -u +%Y%m%dT%H%M%SZ)-$$"
  activation_dir="$activation_transactions/$activation_id"
  mkdir -m 700 -- "$activation_dir"
  : > "$activation_dir/run.log"
  chmod 600 -- "$activation_dir/run.log"
  activation_phase=created
  activation_old_system=$(readlink -f /run/current-system 2>/dev/null || true)
  activation_old_home=$(readlink -f "$HOME/.local/state/nix/profiles/home-manager" 2>/dev/null || true)
  activation_new_system=
  activation_new_home=
  activation_old_lock=
  activation_new_lock=
  activation_state_save
}

activation_set_phase() {
  activation_phase="$1"
  activation_state_save
}

activation_run_logged() {
  "$@" 2>&1 | tee -a "$activation_dir/run.log"
}

activation_require_capacity() {
  activation_init
  local unresolved=0 directory phase
  for directory in "$activation_transactions"/*; do
    [[ -d "$directory" && ! -L "$directory" && -r "$directory/state" ]] || continue
    phase=$(sed -n 's/^phase=//p' "$directory/state" | head -n 1)
    case "$phase" in
      complete|discarded) ;;
      *) unresolved=$((unresolved + 1)) ;;
    esac
  done
  if (( unresolved >= 3 )); then
    printf 'There are already %s unresolved activation attempts. Resume or discard one before starting another.\n' "$unresolved" >&2
    return 1
  fi
}

activation_prune_completed() {
  local kept=0 entry directory phase
  local -a entries=()
  mapfile -t entries < <(find "$activation_transactions" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' | sort -nr)
  for entry in "${entries[@]}"; do
    directory="${entry#* }"
    phase=$(sed -n 's/^phase=//p' "$directory/state" 2>/dev/null | head -n 1)
    [[ "$phase" == complete ]] || continue
    kept=$((kept + 1))
    if (( kept > 5 )); then
      rm -rf -- "$directory"
    fi
  done
}

activation_list() {
  activation_init
  local directory id phase kind snapshot
  for directory in "$activation_transactions"/*; do
    [[ -d "$directory" && ! -L "$directory" && -r "$directory/state" ]] || continue
    id=$(sed -n 's/^id=//p' "$directory/state" | head -n 1)
    kind=$(sed -n 's/^kind=//p' "$directory/state" | head -n 1)
    phase=$(sed -n 's/^phase=//p' "$directory/state" | head -n 1)
    snapshot=$(sed -n 's/^snapshot=//p' "$directory/state" | head -n 1)
    printf '%s\t%s\t%s\t%s\n' "$id" "$kind" "$phase" "$snapshot"
  done
}

activation_discard() {
  activation_state_load "$1"
  activation_lock
  rm -rf -- "$activation_dir"
  printf 'Discarded activation attempt %s and its candidate roots/logs.\n' "$activation_id"
}

activation_accept_update_lock() {
  local lock_temporary
  lock_temporary=$(mktemp "$activation_repo/.flake.lock.XXXXXX")
  if ! cp -- "$activation_new_lock" "$lock_temporary"; then
    rm -f -- "$lock_temporary"
    return 1
  fi
  chmod 644 -- "$lock_temporary"
  if ! mv -f -- "$lock_temporary" "$activation_repo/flake.lock"; then
    rm -f -- "$lock_temporary"
    return 1
  fi
}

activation_build_pair() {
  local host_name="$1" home_profile="$2"
  if [[ ! -e "$activation_dir/system" ]]; then
    activation_set_phase building_system
    if ! activation_run_logged "${NIX_COMMAND:-nix}" build \
      --out-link "$activation_dir/system" --no-write-lock-file \
      "$activation_snapshot#nixosConfigurations.${host_name}.config.system.build.toplevel"; then
      activation_set_phase failed_build_system
      printf 'System build failed. Attempt %s is retained at %s.\n' "$activation_id" "$activation_dir" >&2
      return 1
    fi
    activation_new_system=$(readlink -f "$activation_dir/system")
    activation_state_save
  fi

  if [[ ! -e "$activation_dir/home" ]]; then
    activation_set_phase building_home
    if ! activation_run_logged "${NIX_COMMAND:-nix}" build \
      --out-link "$activation_dir/home" --no-write-lock-file \
      "$activation_snapshot#homeConfigurations.\"${home_profile}\".activationPackage"; then
      activation_set_phase failed_build_home
      printf 'Home Manager build failed. Attempt %s is retained at %s.\n' "$activation_id" "$activation_dir" >&2
      return 1
    fi
    activation_new_home=$(readlink -f "$activation_dir/home")
    activation_state_save
  fi

  activation_new_system=$(readlink -f "$activation_dir/system")
  activation_new_home=$(readlink -f "$activation_dir/home")
  activation_set_phase built
}

activation_apply_pair() {
  local skip_system="${1:-false}"
  local lock_held="${2:-false}"
  if [[ "$lock_held" != true ]]; then activation_lock; fi

  if [[ "$activation_kind" == rebuild ]]; then
    local current_snapshot
    if ! current_snapshot=$("${NIX_COMMAND:-nix}" flake metadata --json --no-write-lock-file "$activation_repo" | jq -er .path) ||
      [[ "$current_snapshot" != "$activation_snapshot" ]]; then
      activation_set_phase blocked_stale_snapshot
      printf 'The source changed after attempt %s was built; refusing to activate stale closures. Start a new rebuild or inspect the saved attempt.\n' "$activation_id" >&2
      return 1
    fi
  fi

  if [[ "$skip_system" != true ]]; then
    activation_set_phase activating_system
    if ! activation_run_logged "${NH_COMMAND:-nh}" os switch "$activation_dir/system"; then
      activation_set_phase failed_system_activation
      printf 'System activation failed. Attempt %s is retained; resume with gnesha-rebuild --resume %s.\n' "$activation_id" "$activation_id" >&2
      return 1
    fi
    activation_set_phase system_activated
  fi

  activation_set_phase activating_home
  if ! activation_run_logged "${NH_COMMAND:-nh}" home switch "$activation_dir/home" -b backup; then
    activation_set_phase failed_home_activation
    printf 'Home Manager activation failed after the system switch. Attempt %s is retained; resume with gnesha-rebuild --resume %s.\n' "$activation_id" "$activation_id" >&2
    return 1
  fi

  activation_set_phase complete
  activation_prune_completed
  printf 'System and Home Manager activation completed from attempt %s.\n' "$activation_id"
}

activation_resume() {
  activation_state_load "$1"
  local host_name="${2:?host name is required}" home_profile="${3:?Home Manager profile is required}"
  if [[ "$activation_phase" == complete ]]; then
    printf 'Activation attempt %s is already complete.\n' "$activation_id" >&2
    return 2
  fi
  if [[ ! -e "$activation_dir/system" || ! -e "$activation_dir/home" ]]; then
    [[ -d "$activation_snapshot" ]] || {
      printf 'The saved snapshot or candidate closures are missing; attempt %s cannot be resumed.\n' "$activation_id" >&2
      return 1
    }
    activation_build_pair "$host_name" "$home_profile" || return 1
  else
    activation_new_system=$(readlink -f "$activation_dir/system")
    activation_new_home=$(readlink -f "$activation_dir/home")
  fi

  local skip_system=false
  case "$activation_phase" in
    system_activated|activating_home|failed_home_activation) skip_system=true ;;
  esac
  if [[ "$activation_kind" == update ]]; then
    activation_lock
    if [[ -z "$activation_repo" || -z "$activation_old_lock" ||
      -z "$activation_new_lock" || ! -r "$activation_old_lock" ||
      ! -r "$activation_new_lock" ]]; then
      activation_set_phase blocked_lock_mismatch
      printf 'Saved lock files are missing; refusing to resume %s.\n' "$activation_id" >&2
      return 1
    fi
    case "$activation_phase" in
      candidate_ready|accepting_lock)
        if cmp -s "$activation_repo/flake.lock" "$activation_old_lock"; then
          activation_set_phase accepting_lock
          if ! activation_accept_update_lock; then
            activation_set_phase failed_lock_acceptance
            printf 'Could not accept the saved candidate lock for %s.\n' "$activation_id" >&2
            return 1
          fi
          activation_set_phase lock_accepted
        elif cmp -s "$activation_repo/flake.lock" "$activation_new_lock"; then
          activation_set_phase lock_accepted
        else
          activation_set_phase blocked_lock_mismatch
          printf 'The repository lock matches neither saved lock for attempt %s; refusing activation.\n' "$activation_id" >&2
          return 1
        fi
        ;;
      *)
        if ! cmp -s "$activation_repo/flake.lock" "$activation_new_lock"; then
          activation_set_phase blocked_lock_mismatch
          printf 'The repository lock no longer matches this update attempt; refusing activation of %s.\n' "$activation_id" >&2
          return 1
        fi
        ;;
    esac
    activation_apply_pair "$skip_system" true
  else
    activation_apply_pair "$skip_system"
  fi
}
