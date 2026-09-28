#!/usr/bin/env bash
set -euo pipefail

helper=${1:?usage: calcurse-daemon-optin-stubs.sh /path/to/helper}
[[ -f "$helper" ]] || { echo "Calcurse daemon condition helper is missing: $helper" >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
config="$work/conf"

expect_disabled() {
  if bash "$helper" "$config"; then
    echo "Calcurse daemon unexpectedly enabled for: $*" >&2
    exit 1
  fi
}

expect_enabled() {
  bash "$helper" "$config" || {
    echo "Calcurse daemon was not enabled for: $*" >&2
    exit 1
  }
}

expect_disabled missing-config
: > "$config"
expect_disabled empty-config
printf '# daemon.enable=yes\n' > "$config"
expect_disabled commented-setting
printf 'daemon.enable=no\n' > "$config"
expect_disabled explicit-no
printf 'daemon.enable = yes\n' > "$config"
expect_enabled whitespace-around-setting
printf 'daemon.enable=yes\ndaemon.enable=no\n' > "$config"
expect_disabled last-setting-no
printf 'daemon.enable=no\ndaemon.enable=yes # explicit opt-in\n' > "$config"
expect_enabled last-setting-yes

echo 'Calcurse daemon opt-in fixtures passed'
