#!/usr/bin/env bash
# Variables are consumed by the sourced activation library.
# shellcheck disable=SC1090,SC2034
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

# Unresolved attempts remain available for review but do not block new work.
activation_state_root="$work/capacity-state"
activation_transactions="$activation_state_root/transactions"
activation_lock_file="$activation_state_root/activation.lock"
prepare_attempt rebuild-old-build rebuild failed_build_system "$work/snapshot-current"
prepare_attempt rebuild-old-system rebuild failed_system_activation "$work/snapshot-current"
prepare_attempt rebuild-stale-closure rebuild blocked_stale_snapshot "$work/snapshot-old"
activation_create rebuild "$work/snapshot-current" "$work/repo"
assert_phase "$activation_id" created
for id in rebuild-old-build rebuild-old-system rebuild-stale-closure; do
  [[ -s "$activation_transactions/$id/state" ]]
done

# Terminal logging must preserve the child TTY, literal arguments, and failures.
printf '#!%s\n' "$(command -v bash)" > "$work/bin/tty-probe"
cat >> "$work/bin/tty-probe" <<'EOF'
[[ -t 0 && -t 1 ]] || exit 91
[[ "$1" == 'a space' && "$2" == 'literal $value; command' ]] || exit 92
printf 'TTY and arguments preserved\n'
exit 7
EOF
printf '#!%s\n' "$(command -v bash)" > "$work/bin/tty-runner"
cat >> "$work/bin/tty-runner" <<'EOF'
set -euo pipefail
source "$ACTIVATION_LIB"
activation_dir="$TTY_LOG_DIR"
activation_run_logged_tty "$TTY_PROBE" 'a space' 'literal $value; command'
EOF
chmod +x "$work/bin/tty-probe" "$work/bin/tty-runner"
ACTIVATION_LIB=$(realpath "$activation_state_lib")
export ACTIVATION_LIB
export TTY_LOG_DIR="$activation_dir" TTY_PROBE="$work/bin/tty-probe"
if SHELL="$BASH" script --quiet --return --command "$work/bin/tty-runner" "$work/outer.log" \
  < /dev/null > "$work/tty-output"; then
  echo "TTY child failure was lost" >&2
  exit 1
else
  [[ $? == 7 ]]
fi
grep -q 'TTY and arguments preserved' "$activation_dir/run.log"
if activation_run_logged_tty bash -c 'exit 8' > "$work/plain-output"; then
  echo "noninteractive child failure was lost" >&2
  exit 1
else
  [[ $? == 8 ]]
fi

# A summary failure must never turn a completed activation into a failed one.
prepare_attempt rebuild-summary-failure rebuild built "$work/snapshot-current"
mkdir -p "$work/previous-system" "$work/previous-home"
activation_old_system="$work/previous-system"
activation_old_home="$work/previous-home"
export NVD_COMMAND=false
activation_apply_pair
assert_phase rebuild-summary-failure complete
unset NVD_COMMAND

# Build cancellation is retained as cancellation, never activation or failure.
cat > "$work/bin/build-monitor" <<'EOF'
#!/usr/bin/env bash
exit "${BUILD_STUB_STATUS:-130}"
EOF
chmod +x "$work/bin/build-monitor"
export BUILD_MONITOR_COMMAND="$work/bin/build-monitor"
for layer in system home; do
  prepare_attempt "rebuild-cancel-$layer" rebuild building_system "$work/snapshot-current"
  if [[ "$layer" == home ]]; then
    ln -s "$work/system-closure" "$activation_dir/system"
  fi
  status=0
  activation_build_pair cf-fv1 lg@cf-fv1 > "$work/build-output" 2>&1 || status=$?
  [[ "$status" == 130 ]]
  assert_phase "rebuild-cancel-$layer" "cancelled_build_$layer"
  grep -q 'build cancelled' "$work/build-output"
  grep -q 'Preparing the build plan' "$work/build-output"
  [[ ! -e "$activation_dir/home" ]]
done
export BUILD_STUB_STATUS=17
prepare_attempt rebuild-build-failure rebuild building_system "$work/snapshot-current"
if activation_build_pair cf-fv1 lg@cf-fv1 > "$work/build-output" 2>&1; then
  echo "failed build unexpectedly succeeded" >&2
  exit 1
fi
assert_phase rebuild-build-failure failed_build_system
grep -q 'Full build events:' "$work/build-output"

echo "activation helper stub checks passed"
