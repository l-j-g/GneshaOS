#!/usr/bin/env bash
set -euo pipefail

helper="$1"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin"
real_bash=$(command -v bash)
real_sleep=$(command -v sleep)
printf '#!%s\n' "$real_bash" > "$work/bin/curl"
cat >> "$work/bin/curl" <<'EOF'
set -euo pipefail
url="${!#}"
count=0
[[ ! -f "$CURL_CALLS" ]] || count=$(<"$CURL_CALLS")
count=$((count + 1))
printf '%s' "$count" > "$CURL_CALLS"
printf '%s\n' "$url" >> "$CURL_URLS"
if [[ "${CURL_ALWAYS_FAIL:-0}" == 1 || "$count" -le "${CURL_FAILS_BEFORE_SUCCESS:-0}" ]]; then
  exit 6
fi
EOF
printf '#!%s\n' "$real_bash" > "$work/bin/sleep"
cat >> "$work/bin/sleep" <<'EOF'
exec "$REAL_SLEEP" "$@"
EOF
chmod +x "$work/bin/curl" "$work/bin/sleep"
export PATH="$work/bin:$PATH" REAL_SLEEP="$real_sleep"

# An initially unavailable network becomes usable before the bounded deadline.
export CURL_CALLS="$work/delayed.calls" CURL_URLS="$work/delayed.urls"
export CURL_FAILS_BEFORE_SUCCESS=2
unset CURL_ALWAYS_FAIL || true
UPDATE_NETWORK_READY_TIMEOUT=10 UPDATE_NETWORK_READY_INTERVAL=1 \
  bash "$helper" >"$work/delayed.stdout" 2>"$work/delayed.stderr"
[[ "$(<"$CURL_CALLS")" -eq 4 ]]
grep -Fxq 'https://api.github.com/repos/NixOS/nixpkgs/git/ref/heads/nixos-unstable' "$work/delayed.urls"
grep -Fxq 'https://cache.nixos.org/nix-cache-info' "$work/delayed.urls"
grep -Fq 'GitHub and the Nix cache are reachable' "$work/delayed.stdout"

# A persistent outage fails within the small fixture deadline.
export CURL_CALLS="$work/offline.calls" CURL_URLS="$work/offline.urls"
export CURL_ALWAYS_FAIL=1
unset CURL_FAILS_BEFORE_SUCCESS || true
offline_started=$SECONDS
if UPDATE_NETWORK_READY_TIMEOUT=2 UPDATE_NETWORK_READY_INTERVAL=1 \
  bash "$helper" >"$work/offline.stdout" 2>"$work/offline.stderr"; then
  echo 'network readiness unexpectedly succeeded during a persistent outage' >&2
  exit 1
fi
offline_elapsed=$((SECONDS - offline_started))
offline_calls=$(<"$CURL_CALLS")
grep -Fq 'external connectivity was not ready within 2s' "$work/offline.stderr"
[[ "$offline_calls" -ge 1 && "$offline_calls" -le 2 ]]
[[ "$offline_elapsed" -le 3 ]]

echo 'update network readiness stub checks passed'
