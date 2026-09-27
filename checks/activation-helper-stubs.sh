#!/usr/bin/env bash
set -euo pipefail

activation_state_lib="$1"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

mkdir -p "$work/bin" "$work/repo" "$work/snapshot-old" "$work/snapshot-current"
printf '#!%s\n' "$(command -v bash)" > "$work/bin/nix"
cat >> "$work/bin/nix" <<'EOF'
set -euo pipefail
if [[ "$1" == flake && "$2" == metadata ]]; then
  printf '{"path":"%s"}\n' "$CURRENT_SNAPSHOT"
  exit 0
fi
echo "unexpected nix invocation: $*" >&2
exit 90
EOF
printf '#!%s\n' "$(command -v bash)" > "$work/bin/nh"
cat >> "$work/bin/nh" <<'EOF'
set -euo pipefail
printf '%s\n' "$*" >> "$NH_LOG"
[[ "${NH_FAIL:-}" != "$*" ]]
EOF
chmod +x "$work/bin/nix" "$work/bin/nh"
export PATH="$work/bin:$PATH"
export NIX_COMMAND="$work/bin/nix"
export NH_COMMAND="$work/bin/nh"
export NH_LOG="$work/nh.log"
export GNESHA_ACTIVATION_STATE_ROOT="$work/state"
export CURRENT_SNAPSHOT="$work/snapshot-current"

source "$activation_state_lib"

prepare_attempt() {
  local id="$1" kind="$2" phase="$3" snapshot="$4"
  activation_id="$id"
  activation_kind="$kind"
  activation_phase="$phase"
  activation_snapshot="$snapshot"
  activation_repo="$work/repo"
  activation_dir="$activation_transactions/$id"
  activation_old_system=
  activation_old_home=
  activation_new_system="$work/system-closure"
  activation_new_home="$work/home-closure"
  activation_old_lock=
  activation_new_lock=
  mkdir -p "$activation_dir"
  activation_state_save
}

assert_phase() {
  local id="$1" expected="$2" actual
  actual=$(sed -n 's/^phase=//p' "$activation_transactions/$id/state")
  [[ "$actual" == "$expected" ]] || {
    echo "expected $id phase $expected, got $actual" >&2
    exit 1
  }
}

# Stale source must be rejected before any activation command is called.
prepare_attempt rebuild-stale rebuild built "$work/snapshot-old"
if ( activation_apply_pair ); then
  echo "stale source unexpectedly reached activation" >&2
  exit 1
fi
assert_phase rebuild-stale blocked_stale_snapshot
[[ ! -e "$NH_LOG" ]]

# A failed NixOS switch must stop before the Home Manager switch.
: > "$NH_LOG"
prepare_attempt update-system-failure update built "$work/snapshot-current"
export NH_FAIL="os switch $activation_dir/system"
if ( activation_apply_pair ); then
  echo "stubbed NixOS switch unexpectedly succeeded" >&2
  exit 1
fi
assert_phase update-system-failure failed_system_activation
[[ "$(cat "$NH_LOG")" == "os switch $activation_dir/system" ]]
unset NH_FAIL

# Resuming a failed Home Manager activation must reuse the system generation.
: > "$NH_LOG"
prepare_attempt rebuild-home-failure rebuild failed_home_activation "$work/snapshot-current"
mkdir -p "$work/system-closure" "$work/home-closure"
ln -s "$work/system-closure" "$activation_dir/system"
ln -s "$work/home-closure" "$activation_dir/home"
activation_state_save
activation_resume rebuild-home-failure cf-fv1 lg@cf-fv1
assert_phase rebuild-home-failure complete
[[ "$(cat "$NH_LOG")" == "home switch $activation_dir/home -b backup" ]]

echo "activation helper stub checks passed"
