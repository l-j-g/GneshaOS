#!/usr/bin/env bash
# Prepare updated closures and publish their paths/counts without activating.
set -euo pipefail
state=$1
flake=$2
host_name=$3
home_profile=$4
network_ready=$5
# The system service runs as the account owner, outside the desktop environment.
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
notify_updates() {
  notify-send --app-name='Gnesha Updates' --icon=system-software-update "$@" 2>/dev/null || true
}
# Rebuild holds this lock while it activates. Advancing flake.lock under
# an in-flight activation would change what that activation resolves to.
activation_lock="$HOME/.local/state/gnesha-activation/activation.lock"
install -d -m 0700 "$state"
exec 9>"$state/lock"
flock -n 9 || exit 0
if [ -e "$activation_lock" ]; then
  exec 8>"$activation_lock"
  if ! flock -n 8; then
    echo "A rebuild is in progress; skipping lock refresh." >&2
    exit 0
  fi
fi
candidate=""
cleanup() {
  local status=$?
  if [ -n "$candidate" ]; then rm -rf -- "$candidate"; fi
  if [ "$status" -ne 0 ]; then
    notify_updates 'Package update preparation failed' 'Run update-status for details.'
  fi
  return "$status"
}
trap cleanup EXIT
"$network_ready"
candidate=$(mktemp -d "$state/refreshed.XXXXXX")
notify_updates 'Downloading package updates…' 'Preparing system and Home Manager packages in the background.'
before=$(jq -r .nodes.nixpkgs.locked.rev "$flake/flake.lock")
# Advance the lock in the working tree only. Nothing is committed here;
# rebuild and the next commit pick it up.
nix flake update --flake "$flake"
after=$(jq -r .nodes.nixpkgs.locked.rev "$flake/flake.lock")
if [ "$before" = "$after" ]; then
  echo "flake.lock already current; preparing closures and cached counts."
else
  echo "nixpkgs $before -> $after"
fi
nix build --max-jobs 1 --cores 2 --no-link \
  "$flake#nixosConfigurations.${host_name}.config.system.build.toplevel"
nix build --max-jobs 1 --cores 2 --no-link \
  "$flake#homeConfigurations.\"${home_profile}\".activationPackage"
system_path=$(nix eval --raw \
  "$flake#nixosConfigurations.${host_name}.config.system.build.toplevel")
home_path=$(nix eval --raw \
  "$flake#homeConfigurations.\"${home_profile}\".activationPackage")
# Record the closures so a review can diff without re-evaluating.
printf '%s\n' "$system_path" > "$candidate/system-path"
printf '%s\n' "$home_path" > "$candidate/home-path"
# Cache upgrade counts next to the closures. awk emits one zero for an
# unchanged closure, and pipefail still propagates a failed nvd invocation.
system_count=$(nvd diff /run/current-system "$system_path" \
  | awk '/^\[U/ { count++ } END { print count+0 }')
home_count=$(nvd diff "$HOME/.local/state/nix/profiles/home-manager" "$home_path" \
  | awk '/^\[U/ { count++ } END { print count+0 }')
printf '%s %s\n' "$system_count" "$home_count" > "$candidate/count"
date --iso-8601=seconds > "$candidate/built-at"
previous=$(readlink "$state/refreshed" || true)
ln -sfn "$candidate" "$state/refreshed.new"
mv -Tf "$state/refreshed.new" "$state/refreshed"
candidate=""
case "$previous" in "$state"/refreshed.*) rm -rf -- "$previous" ;; esac
echo "Refreshed: $system_count system and $home_count home package updates ready."
notify_updates 'Package updates ready' "$system_count system and $home_count home package updates prepared."
