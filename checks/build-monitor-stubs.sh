#!/usr/bin/env bash
# Exercise the display filter with synthetic Nix events, without real builds.
set -euo pipefail
monitor="$1"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
printf '#!%s\n' "$(command -v bash)" > "$work/nix"
cat >> "$work/nix" <<'STUB'
cat >&2 <<'EVENTS'
@nix {"action":"start","id":1,"type":105,"level":3,"text":"building test","fields":["test.drv","","",1]}
@nix {"action":"result","id":1,"type":101,"fields":[" 44 57.85M 44 25.79M 0 0 183.3k 0 05:23 02:24 02:59 11477"]}
@nix {"action":"result","id":1,"type":101,"fields":["curl: (22) HTTP error"]}
@nix {"action":"result","id":1,"type":101,"fields":["Running phase: unpackPhase"]}
@nix {"action":"msg","level":0,"msg":"error: build failed"}
@nix malformed event
plain diagnostic
EVENTS
exit 17
STUB
printf '#!%s\n' "$(command -v bash)" > "$work/nom"
cat >> "$work/nom" <<'STUB'
cat
STUB
chmod +x "$work/nix" "$work/nom"
export PATH="$work:$PATH"
export SUDO_COMMAND=should-not-be-used
export NIX_COMMAND="$work/nix" NOM_COMMAND="$work/nom"
export GNESHA_BUILD_LOG="$work/events.jsonl"
status=0
bash "$monitor" build test > "$work/display" || status=$?
[[ "$status" == 17 ]]
if grep -q '57.85M' "$work/display"; then
  echo 'curl progress leaked into the display' >&2
  exit 1
fi
grep -q '57.85M' "$GNESHA_BUILD_LOG"
for expected in '"action":"start"' 'curl: (22)' 'unpackPhase' 'error: build failed' 'malformed event' 'plain diagnostic'; do
  grep -Fq "$expected" "$work/display"
done
printf 'Build monitor filtering and failure propagation passed\n'

# Cache bootstrap elevates only the Nix client, preserving user-owned logs.
printf '#!%s\n' "$(command -v bash)" > "$work/sudo"
cat >> "$work/sudo" <<'STUB'
printf '%s\n' "$@" > "$SUDO_LOG"
[[ "$1" == -- ]] || exit 91
shift
exec "$@"
STUB
chmod +x "$work/sudo"
export GNESHA_SUDO="$work/sudo" SUDO_LOG="$work/sudo-args"
status=0
GNESHA_BUILD_AS_ROOT=true bash "$monitor" build 'literal space' > "$work/root-display" || status=$?
[[ "$status" == 17 ]]
[[ $(sed -n '1p' "$SUDO_LOG") == -- ]]
[[ $(sed -n '2p' "$SUDO_LOG") == "$NIX_COMMAND" ]]
[[ $(sed -n '4p' "$SUDO_LOG") == 'literal space' ]]
grep -q 'error: build failed' "$work/root-display"
printf 'Build monitor privileged-client checks passed\n'
