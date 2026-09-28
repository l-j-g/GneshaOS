#!/usr/bin/env bash
set -euo pipefail

timeout_seconds=${UPDATE_NETWORK_READY_TIMEOUT:-120}
interval_seconds=${UPDATE_NETWORK_READY_INTERVAL:-5}
case "$timeout_seconds:$interval_seconds" in
  *[!0-9:]*|:*)
    echo 'gnesha-update-build: network readiness timeout and interval must be positive integers' >&2
    exit 2
    ;;
esac
if (( timeout_seconds < 1 || interval_seconds < 1 )); then
  echo 'gnesha-update-build: network readiness timeout and interval must be positive integers' >&2
  exit 2
fi

started=$SECONDS
probe_url() {
  local url=$1
  local elapsed=$((SECONDS - started))
  local remaining=$((timeout_seconds - elapsed))
  (( remaining > 0 )) || return 1
  timeout "$remaining" curl \
    --fail \
    --silent \
    --show-error \
    --connect-timeout 3 \
    --max-time "$remaining" \
    "$url" >/dev/null 2>&1
}

while (( SECONDS - started < timeout_seconds )); do
  if probe_url 'https://api.github.com/repos/NixOS/nixpkgs/git/ref/heads/nixos-unstable' &&
    probe_url 'https://cache.nixos.org/nix-cache-info'; then
    echo 'gnesha-update-build: GitHub and the Nix cache are reachable.'
    exit 0
  fi

  elapsed=$((SECONDS - started))
  remaining=$((timeout_seconds - elapsed))
  (( remaining > 0 )) || break
  sleep_seconds=$interval_seconds
  (( sleep_seconds <= remaining )) || sleep_seconds=$remaining
  sleep "$sleep_seconds"
done

echo "gnesha-update-build: external connectivity was not ready within ${timeout_seconds}s; no update candidate was started." >&2
exit 1
