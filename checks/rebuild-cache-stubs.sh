#!/usr/bin/env bash
# Exercise cache trust bootstrapping with fake Nix/sudo, never root or a build.
# shellcheck disable=SC1090,SC2034,SC2154
set -euo pipefail
library=$1
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin"
printf '#!%s\n' "$(command -v bash)" > "$work/bin/nix"
cat >> "$work/bin/nix" <<'EOF'
case "$1" in
  eval) [[ ${EVAL_FAIL:-false} == false ]] || exit 17; printf '%s\n' "$TARGET_CACHES" ;;
  config) printf '%s\n' "$ACTIVE_CACHES" ;;
  *) exit 90 ;;
esac
EOF
printf '#!%s\n' "$(command -v bash)" > "$work/bin/sudo"
cat >> "$work/bin/sudo" <<'EOF'
printf '%s\n' "$*" >> "$SUDO_LOG"
exit "${SUDO_STATUS:-0}"
EOF
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH"
export SUDO_COMMAND=should-not-be-used
export NIX_COMMAND="$work/bin/nix" GNESHA_SUDO="$work/bin/sudo" SUDO_LOG="$work/sudo.log"
export TARGET_CACHES='{"substituters":["https://cache.nixos.org/","https://cache.numtide.com"],"keys":["nixos-key","numtide-key"]}'
export ACTIVE_CACHES='{"substituters":{"value":["https://cache.nixos.org/"]},"trusted-substituters":{"value":[]},"trusted-public-keys":{"value":["nixos-key"]}}'
export GNESHA_ACTIVATION_STATE_ROOT="$work/state"
source "$library"
activation_snapshot="$work/snapshot"
activation_dir="$work/attempt"
mkdir -p "$activation_dir"

# Declining new trust must prevent all privilege use.
if activation_prepare_build_caches cf-fv1 <<< n > "$work/decline" 2>&1; then
  echo 'declined cache trust unexpectedly succeeded' >&2; exit 1
fi
[[ ! -e "$SUDO_LOG" ]]
[[ $activation_build_as_root == false ]]

# Approved caches are passed as literal list arguments; only builds use root.
activation_prepare_build_caches cf-fv1 <<< y > "$work/approved" 2>&1
[[ $activation_build_as_root == true ]]
[[ $(cat "$SUDO_LOG") == -v ]]
[[ ${activation_build_options[*]} == '--option extra-substituters https://cache.nixos.org/ https://cache.numtide.com --option extra-trusted-public-keys nixos-key numtide-key' ]]
grep -q 'numtide-key' "$work/approved"
grep -q 'cache.numtide.com' "$work/approved"

# Once active, ordinary builds stay unprivileged and need no approval.
rm "$SUDO_LOG"
export ACTIVE_CACHES='{"substituters":{"value":["https://cache.nixos.org/","https://cache.numtide.com"]},"trusted-substituters":{"value":[]},"trusted-public-keys":{"value":["nixos-key","numtide-key"]}}'
activation_prepare_build_caches cf-fv1 < /dev/null
[[ $activation_build_as_root == false && ! -e "$SUDO_LOG" ]]

# An already allowed but inactive cache only needs unprivileged build flags.
export ACTIVE_CACHES='{"substituters":{"value":["https://cache.nixos.org/"]},"trusted-substituters":{"value":["https://cache.numtide.com"]},"trusted-public-keys":{"value":["nixos-key","numtide-key"]}}'
activation_prepare_build_caches cf-fv1 < /dev/null
[[ $activation_build_as_root == false && ! -e "$SUDO_LOG" ]]

# Replacing a signing key still requires consent, even for an active URL.
export ACTIVE_CACHES='{"substituters":{"value":["https://cache.nixos.org/","https://cache.numtide.com"]},"trusted-substituters":{"value":[]},"trusted-public-keys":{"value":["nixos-key"]}}'
if activation_prepare_build_caches cf-fv1 < /dev/null; then exit 1; fi
[[ ! -e "$SUDO_LOG" ]]

# Privilege failure and evaluation failure must stop the attempt.
export SUDO_STATUS=1
if activation_prepare_build_caches cf-fv1 <<< y; then exit 1; fi
[[ $activation_build_as_root == false ]]
export EVAL_FAIL=true
if activation_prepare_build_caches cf-fv1 <<< y; then exit 1; fi

# Both closures receive approved trust; a refusal blocks both build phases.
unset EVAL_FAIL SUDO_STATUS
printf '#!%s\n' "$(command -v bash)" > "$work/bin/monitor"
cat >> "$work/bin/monitor" <<'EOF'
printf '%s %s\n' "$GNESHA_BUILD_AS_ROOT" "$*" >> "$MONITOR_LOG"
while [[ $# -gt 0 ]]; do
  if [[ $1 == --out-link ]]; then
    ln -s "$CLOSURE" "$2"
    break
  fi
  shift
done
EOF
chmod +x "$work/bin/monitor"
export BUILD_MONITOR_COMMAND="$work/bin/monitor" MONITOR_LOG="$work/monitor.log" CLOSURE="$work/closure"
mkdir "$CLOSURE"
activation_create rebuild "$activation_snapshot" "$work/repo" > /dev/null
if activation_build_pair cf-fv1 lg@cf-fv1 <<< n > /dev/null 2>&1; then exit 1; fi
[[ ! -e "$MONITOR_LOG" && $activation_phase == blocked_cache_setup ]]
activation_build_pair cf-fv1 lg@cf-fv1 <<< y > /dev/null
[[ $activation_phase == built ]]
[[ $(wc -l < "$MONITOR_LOG") == 2 ]]
[[ $(grep -c '^true build --option extra-substituters ' "$MONITOR_LOG") == 2 ]]
grep -Fq '#nixosConfigurations.cf-fv1.config.system.build.toplevel' "$MONITOR_LOG"
grep -Fq '#homeConfigurations."lg@cf-fv1".activationPackage' "$MONITOR_LOG"
[[ -e "$activation_dir/system" && -e "$activation_dir/home" ]]

# An already built pair is reused without reevaluating or requesting trust.
export EVAL_FAIL=true
activation_build_pair cf-fv1 lg@cf-fv1 < /dev/null > /dev/null
[[ $(wc -l < "$MONITOR_LOG") == 2 ]]

printf 'Rebuild cache approval and trust checks passed\n'
