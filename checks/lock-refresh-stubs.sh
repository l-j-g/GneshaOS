#!/usr/bin/env bash
# Exercise background refresh without updating inputs or building packages.
set -euo pipefail
helper=$1
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin" "$work/home" "$work/flake"
printf '{"nodes":{"nixpkgs":{"locked":{"rev":"fixture"}}}}\n' > "$work/flake/flake.lock"
export HOME="$work/home" CALLS="$work/calls"
real_bash=$(command -v bash)
for name in nix nvd network-ready notify-send; do
  printf '#!%s\n' "$real_bash" > "$work/bin/$name"
done
cat >> "$work/bin/nix" <<'STUB'
set -euo pipefail
printf 'nix %s\n' "$*" >> "$CALLS"
case "$1" in
  build) [[ ${FAIL_BUILD:-0} == 0 ]] ;;
  eval) printf '/fixture/closure\n' ;;
esac
STUB
cat >> "$work/bin/nvd" <<'STUB'
set -euo pipefail
if [[ ${FAIL_DIFF:-0} == 1 ]]; then exit 19; fi
if [[ ${HAS_UPGRADE:-0} == 1 ]]; then printf '[U] fixture 1 -> 2\n'; fi
STUB
cat >> "$work/bin/network-ready" <<'STUB'
printf 'network-ready\n' >> "$CALLS"
STUB
cat >> "$work/bin/notify-send" <<'STUB'
printf 'toast: %s\n' "$*" >> "$CALLS"
exit "${FAIL_NOTIFY:-0}"
STUB
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH"
state="$HOME/.local/state/gnesha-lock-refresh"
refresh() {
  bash "$helper" "$state" "$work/flake" fixture fixture@fixture "$work/bin/network-ready"
}
# Fresh login: no state directory exists yet. Zero upgrades must be two numbers.
refresh
[[ $(stat -c %a "$state") == 700 ]]
[[ $(cat "$state/refreshed/count") == '0 0' ]]
[[ $(cat "$state/refreshed/system-path") == /fixture/closure ]]
[[ $(cat "$state/refreshed/home-path") == /fixture/closure ]]
[[ -s "$state/refreshed/built-at" ]]
grep -Fq 'Downloading package updates…' "$CALLS"
grep -Fq '0 system and 0 home package updates prepared.' "$CALLS"
# A held refresh lock must prevent network, updates, and builds.
: > "$CALLS"
exec 9>"$state/lock"
flock 9
refresh
[[ ! -s "$CALLS" ]]
exec 9>&-
# Rebuild's activation lock must also exclude refresh work.
mkdir -p "$HOME/.local/state/gnesha-activation"
exec 8>"$HOME/.local/state/gnesha-activation/activation.lock"
flock 8
refresh
[[ ! -s "$CALLS" ]]
exec 8>&-
# Both closures' counts are published together and replaced on success.
FAIL_NOTIFY=1 HAS_UPGRADE=1 refresh
[[ $(cat "$state/refreshed/count") == '1 1' ]]
previous=$(readlink "$state/refreshed")
# Build/diff failures must preserve the previous complete result and clean up.
for failure in FAIL_BUILD FAIL_DIFF; do
  : > "$CALLS"
  if env "$failure=1" bash "$helper" "$state" "$work/flake" fixture fixture@fixture "$work/bin/network-ready"; then
    echo "$failure unexpectedly succeeded" >&2
    exit 1
  fi
  grep -Fq 'Package update preparation failed' "$CALLS"
  [[ $(readlink "$state/refreshed") == "$previous" ]]
  shopt -s nullglob
  candidates=("$state"/refreshed.*)
  [[ ${#candidates[@]} == 1 ]]
done
echo 'lock refresh checks passed: fresh state, counts, locks, recovery, optional toasts.'
