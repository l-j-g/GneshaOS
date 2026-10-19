#!/usr/bin/env bash
# Validate the share and its source-address policy without starting Samba.
set -euo pipefail
config=$1
expected_user=$2
expected_path=$3
testparm -s "$config" >/dev/null
for address in 127.0.0.1 ::1 192.168.1.50 100.100.0.2; do
  output=$(testparm -s "$config" fixture "$address" 2>&1)
  grep -Fq "Allow connection from fixture ($address) to media" <<< "$output"
done
for address in 192.168.2.50 100.128.0.2 203.0.113.50 2001:db8::1; do
  output=$(testparm -s "$config" fixture "$address" 2>&1)
  grep -Fq "Deny connection from fixture ($address) to media" <<< "$output"
done
parameter() {
  testparm -s --section-name="$1" --parameter-name="$2" "$config" 2>/dev/null
}
[[ $(parameter media 'valid users') == "$expected_user" ]]
[[ $(parameter media 'force user') == "$expected_user" ]]
[[ $(parameter media path) == "$expected_path" ]]
[[ $(parameter media 'guest ok') == No ]]
[[ $(parameter global 'server min protocol') == SMB2 ]]
echo 'Samba checks passed: valid config, LAN/tailnet access, outside denial, authenticated SMB2 share.'
