#!/usr/bin/env bash
# Exercise the display filter with synthetic Nix events, without real builds.
set -euo pipefail
monitor="$1"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cat > "$work/nix" <<'STUB'
#!/usr/bin/env bash
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
cat > "$work/nom" <<'STUB'
#!/usr/bin/env bash
cat
STUB
chmod +x "$work/nix" "$work/nom"
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
