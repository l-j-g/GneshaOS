#!/usr/bin/env bash
# Validate update ordering/failure isolation without downloads or activation.
# Variables and hooks are consumed by the sourced helpers.
# shellcheck disable=SC2034,SC1090,SC2329
set -euo pipefail
helper=$1
state_lib=$2
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin" "$work/repo"
export CALLS="$work/calls" REBUILD_FIXTURE="$work"
cat > "$work/bin/nix" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'nix %s\n' "$*" >> "$CALLS"
# Both update and metadata must run while the real activation lock is held.
if flock -n "$REBUILD_FIXTURE/state/activation.lock" true; then
  echo 'snapshot/update ran without the lock' >&2
  exit 90
fi
case "$1 $2" in
  'flake update') exit "${UPDATE_STATUS:-0}" ;;
  'flake metadata')
    if [[ ${METADATA_STATUS:-0} != 0 ]]; then exit "$METADATA_STATUS"; fi
    printf '{"path":"/fixture/frozen"}\n' ;;
  *) exit 91 ;;
esac
STUB
chmod +x "$work/bin/nix"
export PATH="$work/bin:$PATH"
run_helper() (
  set -euo pipefail
  activation_state_root="$work/state"
  source "$state_lib"
  flakePath="$work/repo"
  hostName=fixture
  homeProfile=fixture@fixture
  activation_create() { printf 'create %s\n' "$*" >> "$CALLS"; }
  activation_build_pair() { printf 'build %s\n' "$*" >> "$CALLS"; return "${BUILD_STATUS:-0}"; }
  activation_apply_pair() { printf 'activate\n' >> "$CALLS"; }
  source "$helper"
)
: > "$CALLS"
run_helper --update > "$work/output" 2>&1 || { cat "$work/output"; exit 1; }
mapfile -t calls < "$CALLS"
[[ ${calls[0]} == "nix flake update --flake $work/repo" ]]
[[ ${calls[1]} == "nix flake metadata --json --no-write-lock-file $work/repo" ]]
[[ ${calls[2]} == 'create rebuild /fixture/frozen '* ]]
[[ ${calls[3]} == 'build fixture fixture@fixture' ]]
[[ ${calls[4]} == activate ]]
: > "$CALLS"
run_helper > "$work/output" 2>&1
if grep -q 'flake update' "$CALLS"; then echo 'Pinned rebuild updated inputs' >&2; exit 1; fi
grep -q activate "$CALLS"
: > "$CALLS"
if UPDATE_STATUS=42 run_helper --update > "$work/output" 2>&1; then
  echo 'Failed update unexpectedly succeeded' >&2; exit 1
fi
[[ $(wc -l < "$CALLS") == 1 ]]
if grep -Eq 'metadata|build|activate' "$CALLS"; then echo 'Continued after update failure' >&2; exit 1; fi
: > "$CALLS"
if METADATA_STATUS=1 run_helper --update > "$work/output" 2>&1; then
  echo 'Failed snapshot unexpectedly succeeded' >&2; exit 1
fi
if grep -Eq '^build|^activate' "$CALLS"; then echo 'Continued after snapshot failure' >&2; exit 1; fi
flock -n "$work/state/activation.lock" true
: > "$CALLS"
if BUILD_STATUS=1 run_helper --update > "$work/output" 2>&1; then
  echo 'Failed build unexpectedly succeeded' >&2; exit 1
fi
if grep -q activate "$CALLS"; then echo 'Activated after build failure' >&2; exit 1; fi
: > "$CALLS"
if run_helper --update unexpected > "$work/output" 2>&1; then
  echo 'Invalid arguments unexpectedly succeeded' >&2; exit 1
fi
[[ ! -s "$CALLS" ]]
echo 'Rebuild update checks passed: ordering, locks, pinned rebuild, failures, arguments.'
