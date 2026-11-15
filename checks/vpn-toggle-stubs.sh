#!/usr/bin/env bash
set -euo pipefail

helper=${1:?usage: vpn-toggle-stubs.sh /path/to/vpn-toggle}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin"
export NMCLI_LOG="$work/nmcli.log"
export ACTIVE_QUERY_FAIL=1
real_bash=$(command -v bash)

printf '#!%s\n' "$real_bash" > "$work/bin/nmcli"
cat >> "$work/bin/nmcli" <<'STUB'
printf '%s\n' "$*" >> "$NMCLI_LOG"
case "$*" in
  'general status') exit 0 ;;
  '--terse --fields UUID connection show') printf '60d25a7b-a0a9-56c7-8a6d-ea7ea3061f65\n' ;;
  '--terse --fields UUID connection show --active')
    if [[ $ACTIVE_QUERY_FAIL == 1 ]]; then exit 1; fi
    printf '\n'
    ;;
  'connection up uuid 60d25a7b-a0a9-56c7-8a6d-ea7ea3061f65'|'connection down uuid 60d25a7b-a0a9-56c7-8a6d-ea7ea3061f65') exit 0 ;;
  *) echo "unexpected nmcli call: $*" >&2; exit 2 ;;
esac
STUB
chmod +x "$work/bin/nmcli"
export PATH="$work/bin:$PATH"

status_output=$(bash "$helper" status)
status_class=$(jq -er '.class' <<< "$status_output")
[[ $status_class == unavailable ]] || {
  echo "active-connection query failure was reported as '$status_class'" >&2
  exit 1
}
jq -e '.tooltip | contains("active NetworkManager connections")' <<< "$status_output" >/dev/null

: > "$NMCLI_LOG"
if bash "$helper" toggle > "$work/toggle.json" 2>/dev/null; then
  echo 'toggle unexpectedly succeeded when active state could not be read' >&2
  exit 1
fi
jq -e '.class == "failed"' "$work/toggle.json" >/dev/null
if grep -Eq '^connection (up|down) uuid 60d25a7b-a0a9-56c7-8a6d-ea7ea3061f65$' "$NMCLI_LOG"; then
  echo 'toggle changed the connection despite not knowing its current state' >&2
  exit 1
fi

echo 'vpn-toggle active-query failure fixture passed'
