#!/usr/bin/env bash
set -Eeuo pipefail

arr_pin=${1:?usage: arr-runtime-stubs.sh /path/to/arr-pin /path/to/arr-wait-ready /build/test-root}
arr_wait_ready=${2:?usage: arr-runtime-stubs.sh /path/to/arr-pin /path/to/arr-wait-ready /build/test-root}
test_root=${3:?usage: arr-runtime-stubs.sh /path/to/arr-pin /path/to/arr-wait-ready /build/test-root}
arr_directory="$test_root/arr"
call_log="$test_root/docker-calls"
state_directory="$test_root/docker-state"
lock="$arr_directory/images.lock.json"
previous_lock="$lock.previous.json"

case "$test_root" in
  /tmp/gnesha-arr-runtime-check|/build/gnesha-arr-runtime-check|/build/*/gnesha-arr-runtime-check) ;;
  *)
  echo "refusing to use a runtime root outside the dedicated build fixture" >&2
  exit 2
  ;;
esac
[[ -x "$arr_pin" ]] || { echo "generated arr-pin command is missing: $arr_pin" >&2; exit 2; }
[[ -x "$arr_wait_ready" ]] || { echo "generated arr-wait-ready command is missing: $arr_wait_ready" >&2; exit 2; }

rm -rf -- "$arr_directory" "$state_directory"
mkdir -p "$arr_directory" "$state_directory"
export GNESHA_ARR_FIXTURE_LOG="$call_log"
export GNESHA_ARR_FIXTURE_STATE="$state_directory"

make_lock() {
  local suffix=$1
  jq -cn --arg suffix "$suffix" '{services: {
    audiobookshelf: {image: ("fixture/audiobookshelf@sha256:" + ($suffix | if . == "old" then "a" else "1" end) * 64)},
    emby: {image: ("fixture/emby@sha256:" + ($suffix | if . == "old" then "b" else "2" end) * 64)},
    gluetun: {image: ("fixture/gluetun@sha256:" + ($suffix | if . == "old" then "c" else "3" end) * 64)},
    lidarr: {image: ("fixture/lidarr@sha256:" + ($suffix | if . == "old" then "d" else "4" end) * 64)},
    prowlarr: {image: ("fixture/prowlarr@sha256:" + ($suffix | if . == "old" then "e" else "5" end) * 64)},
    qbittorrent: {image: ("fixture/qbittorrent@sha256:" + ($suffix | if . == "old" then "f" else "6" end) * 64)},
    sabnzbd: {image: ("fixture/sabnzbd@sha256:" + ($suffix | if . == "old" then "0" else "7" end) * 64)}
  }}'
}

assert_no_docker_calls() {
  [[ ! -s "$call_log" ]] || {
    echo "expected zero Docker calls, got:" >&2
    cat "$call_log" >&2
    exit 1
  }
}

# Corrupt JSON and a validly shaped lock with stale service coverage must be
# rejected before any Docker command can run.
printf '{not-json\n' > "$lock"
: > "$call_log"
if "$arr_pin" --refresh >"$test_root/pin.stdout" 2>"$test_root/pin.stderr"; then
  echo "arr-pin accepted a corrupt image lock" >&2
  exit 1
fi
grep -Fq 'invalid image lock' "$test_root/pin.stderr"
assert_no_docker_calls

jq 'del(.services.emby)' < <(make_lock old) > "$lock"
: > "$call_log"
if "$arr_pin" --refresh >"$test_root/pin.stdout" 2>"$test_root/pin.stderr"; then
  echo "arr-pin accepted incorrect service coverage" >&2
  exit 1
fi
grep -Fq 'invalid image lock' "$test_root/pin.stderr"
assert_no_docker_calls

# A failure partway through pulling must not publish a partial lock or replace
# the previously valid lock.
make_lock old > "$lock"
cp "$lock" "$test_root/lock.before"
: > "$call_log"
export GNESHA_ARR_FIXTURE_MODE=pull-fail
if "$arr_pin" --refresh >"$test_root/pin.stdout" 2>"$test_root/pin.stderr"; then
  echo "arr-pin unexpectedly succeeded after a partial pull failure" >&2
  exit 1
fi
cmp -s "$test_root/lock.before" "$lock" || {
  echo "arr-pin changed the existing lock after a partial pull failure" >&2
  exit 1
}
[[ ! -e "$previous_lock" ]] || {
  echo "arr-pin published a previous lock after a partial pull failure" >&2
  exit 1
}
grep -Fq 'pull' "$call_log"
unset GNESHA_ARR_FIXTURE_MODE

# A complete refresh publishes the new digest lock, retains the exact previous
# manifest, and gives each former digest its rollback tag.
make_lock old > "$lock"
cp "$lock" "$test_root/lock.before"
: > "$call_log"
"$arr_pin" --refresh >"$test_root/pin.stdout"
cmp -s "$test_root/lock.before" "$previous_lock" || {
  echo "arr-pin did not publish the previous manifest intact" >&2
  exit 1
}
jq -e '.services | length == 7 and all(.[]; .image | test("@sha256:[0-9a-f]{64}$"))' "$lock" >/dev/null
for service in audiobookshelf emby gluetun lidarr prowlarr qbittorrent sabnzbd; do
  old_image=$(jq -er --arg service "$service" '.services[$service].image' "$test_root/lock.before")
  rollback_image="${old_image%@*}:gnesha-rollback"
  grep -Fq "image tag $old_image $rollback_image" "$call_log" || {
    echo "arr-pin did not tag the prior $service image for rollback" >&2
    exit 1
  }
done
unset GNESHA_ARR_FIXTURE_MODE

# Services can become healthy after initial inspection; readiness should keep
# polling until every configured service is ready.
: > "$call_log"
rm -f "$state_directory"/*
export GNESHA_ARR_FIXTURE_MODE=delayed-ready
export ARR_READY_TIMEOUT=5 ARR_READY_INTERVAL=1
"$arr_wait_ready" >"$test_root/readiness.stdout" 2>"$test_root/readiness.stderr"
grep -Fq 'arr-update readiness results:' "$test_root/readiness.stdout"
grep -Fq 'audiobookshelf: running healthy' "$test_root/readiness.stdout"
[[ $(wc -l < "$call_log") -gt 7 ]] || {
  echo "arr-wait-ready did not poll again for delayed readiness" >&2
  exit 1
}

# Permanently unready services time out and the final report names every
# service with its last observed state.
: > "$call_log"
rm -f "$state_directory"/*
export GNESHA_ARR_FIXTURE_MODE=permanently-unready
export ARR_READY_TIMEOUT=2 ARR_READY_INTERVAL=1
if "$arr_wait_ready" >"$test_root/timeout.stdout" 2>"$test_root/timeout.stderr"; then
  echo "arr-wait-ready accepted permanently unready services" >&2
  exit 1
fi
grep -Fq 'did not become ready within 2s' "$test_root/timeout.stderr"
grep -Fq 'arr-update readiness results:' "$test_root/timeout.stdout"
for service in audiobookshelf emby gluetun lidarr prowlarr qbittorrent sabnzbd; do
  grep -Fq "$service:" "$test_root/timeout.stdout" || {
    echo "arr-wait-ready final report omitted $service" >&2
    exit 1
  }
done

echo "arr runtime stub checks passed"
