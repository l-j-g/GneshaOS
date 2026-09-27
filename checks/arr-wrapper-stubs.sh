#!/usr/bin/env bash
set -Eeuo pipefail

arr=${1:?usage: arr-wrapper-stubs.sh /path/to/arr /build/test-root}
test_root=${2:?usage: arr-wrapper-stubs.sh /path/to/arr /build/test-root}
arr_directory="$test_root/arr"
call_log="$test_root/docker-calls"

[[ "$test_root" == /build/gnesha-arr-wrapper-check ]] || {
  echo "refusing to use a runtime root outside the dedicated build fixture" >&2
  exit 2
}
[[ -x "$arr" ]] || {
  echo "generated arr command is missing: $arr" >&2
  exit 2
}

mkdir -p "$test_root" "$arr_directory"
rm -rf -- "$arr_directory/config"
rm -f -- "$arr_directory/.env" "$arr_directory/.images-lock" "$arr_directory/images.lock.json" "$call_log"

if "$arr" up -d 2> "$test_root/error"; then
  echo "arr unexpectedly accepted a missing .env file" >&2
  exit 1
fi
grep -Fq 'runtime .env or config/ is missing' "$test_root/error"
[[ ! -s "$call_log" ]]

printf 'synthetic=fixture\n' > "$arr_directory/.env"
if "$arr" up -d 2> "$test_root/error"; then
  echo "arr unexpectedly accepted a missing config directory" >&2
  exit 1
fi
grep -Fq 'runtime .env or config/ is missing' "$test_root/error"
[[ ! -s "$call_log" ]]

mkdir -p "$arr_directory/config"
cat > "$arr_directory/images.lock.json" <<'JSON'
{"services":{"audiobookshelf":{"image":"fixture/audiobookshelf@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"emby":{"image":"fixture/emby@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"},"gluetun":{"image":"fixture/gluetun@sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"},"lidarr":{"image":"fixture/lidarr@sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"},"prowlarr":{"image":"fixture/prowlarr@sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"},"qbittorrent":{"image":"fixture/qbittorrent@sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"},"sabnzbd":{"image":"fixture/sabnzbd@sha256:1111111111111111111111111111111111111111111111111111111111111111"}}}
JSON

export GNESHA_ARR_FIXTURE_LOG="$call_log"
"$arr" up -d

grep -Fq -- "--project-name arr --project-directory $arr_directory --env-file $arr_directory/.env" "$call_log"
grep -Fq -- " up -d" "$call_log"
grep -Fq -- "-f $arr_directory/images.lock.json" "$call_log"
! grep -Fq -- 'stop watchtower' "$call_log"
! grep -Fq -- 'rm watchtower' "$call_log"

echo "arr wrapper stub checks passed"
