#!/usr/bin/env bash
set -Eeuo pipefail

ghostfolio=${1:?usage: ghostfolio-import-recovery-stubs.sh /path/to/ghostfolio /path/to/ghostfolio-pin /build/test-root}
ghostfolio_pin=${2:?usage: ghostfolio-import-recovery-stubs.sh /path/to/ghostfolio /path/to/ghostfolio-pin /build/test-root}
test_root=${3:?usage: ghostfolio-import-recovery-stubs.sh /path/to/ghostfolio /path/to/ghostfolio-pin /build/test-root}
runtime_root="$test_root/ghostfolio"

# This fixture is only safe in its dedicated Nix build sandbox directory.
[[ "$test_root" == /build/gnesha-ghostfolio-import-check ]] || {
  echo "refusing to use a runtime root outside the dedicated build fixture" >&2
  exit 2
}
for command in "$ghostfolio" "$ghostfolio_pin"; do
  [[ -x "$command" ]] || {
    echo "generated Ghostfolio command is missing: $command" >&2
    exit 2
  }
done

reset_fixture() {
  [[ -d "$runtime_root" && ! -L "$runtime_root" ]] || return 0
  rm -rf -- "$runtime_root/postgres"
  rm -f -- \
    "$runtime_root/.database-imported" \
    "$runtime_root/.database-import-state" \
    "$runtime_root/initial-database.sql" \
    "$runtime_root/initial-database.sql.imported" \
    "$runtime_root/images.lock.json" \
    "$runtime_root/images.lock.json.previous.json" \
    "$runtime_root/secrets.env" \
    "$test_root/docker-calls" \
    "$test_root/docker-calls.before-retry" \
    "$test_root/psql-input" \
    "$test_root/timeout-calls" \
    "$test_root/pull-count"
}

mkdir -p "$runtime_root"
trap reset_fixture EXIT

write_prerequisites() {
  mkdir -p "$runtime_root/postgres"
  printf '17\n' > "$runtime_root/postgres/PG_VERSION"
  printf '%s\n' '-- Dumped from database version 17.5' 'SELECT 1;' > "$runtime_root/initial-database.sql"
  printf '%s\n' \
    'DATABASE_PASSWORD=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' \
    'REDIS_PASSWORD=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB' \
    > "$runtime_root/secrets.env"
  chmod 600 "$runtime_root/secrets.env"
  cat > "$runtime_root/images.lock.json" <<'JSON'
{"postgresMajor":"17","services":{"ghostfolio":{"image":"docker.io/ghostfolio/ghostfolio:latest@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"postgres":{"image":"docker.io/library/postgres:17-alpine@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"},"redis":{"image":"docker.io/library/redis:7-alpine@sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"}}}
JSON
}

export GHOSTFOLIO_FIXTURE_ROOT="$test_root"
cat > "$test_root/bash-env" <<'BASH_ENV'
sleep() {
  local delay=${1%s}
  SECONDS=$((SECONDS + delay))
}
timeout() {
  local limit=$1
  shift
  if [ -n "${GHOSTFOLIO_TIMEOUT_LOG:-}" ]; then
    printf '%s %s\n' "$limit" "$*" >> "$GHOSTFOLIO_TIMEOUT_LOG"
  fi
  command timeout "$limit" "$@"
}
BASH_ENV

# An interruption after psql succeeds but before marker finalization must finish
# bookkeeping without replaying the SQL dump.
reset_fixture
write_prerequisites
printf 'imported\n' > "$runtime_root/.database-import-state"
"$ghostfolio" up -d
[[ -e "$runtime_root/.database-imported" ]]
[[ ! -e "$runtime_root/.database-import-state" ]]
[[ ! -e "$runtime_root/initial-database.sql" ]]
[[ -s "$runtime_root/initial-database.sql.imported" ]]
! grep -Fq 'psql' "$test_root/docker-calls"

# A fresh target must wait for PostgreSQL, import the synthetic dump, and
# finalize the marker and dump archive after psql succeeds.
reset_fixture
write_prerequisites
rm -f "$runtime_root/postgres/PG_VERSION"
: > "$test_root/docker-calls"
BASH_ENV="$test_root/bash-env" \
  GHOSTFOLIO_TIMEOUT_LOG="$test_root/timeout-calls" \
  "$ghostfolio" up -d
[[ -e "$runtime_root/.database-imported" ]]
[[ ! -e "$runtime_root/.database-import-state" ]]
[[ ! -e "$runtime_root/initial-database.sql" ]]
[[ -s "$runtime_root/initial-database.sql.imported" ]]
grep -Fq 'exec -T postgres pg_isready' "$test_root/docker-calls"
grep -Fq 'exec -T postgres psql' "$test_root/docker-calls"
grep -Fq 'SELECT 1;' "$test_root/psql-input"
grep -Fq -- "-f $runtime_root/images.lock.json" "$test_root/docker-calls"
grep -Eq '^300s docker compose .* up ' "$test_root/timeout-calls"
grep -Eq '^1800s docker compose .* exec -T postgres psql' "$test_root/timeout-calls"

# A failed SQL command must retain the dump and mark the target failed. A
# subsequent invocation must refuse before making any additional Docker calls.
reset_fixture
write_prerequisites
rm -f "$runtime_root/postgres/PG_VERSION"
: > "$test_root/docker-calls"
if GHOSTFOLIO_PSQL_FAIL=1 "$ghostfolio" up -d 2> "$test_root/error"; then
  echo "Ghostfolio unexpectedly accepted a failed SQL import" >&2
  exit 1
fi
grep -Fq 'SQL import failed' "$test_root/error"
[[ "$(cat "$runtime_root/.database-import-state")" == failed ]]
[[ ! -e "$runtime_root/.database-imported" ]]
[[ -s "$runtime_root/initial-database.sql" ]]
grep -Fq 'exec -T postgres pg_isready' "$test_root/docker-calls"
grep -Fq 'exec -T postgres psql' "$test_root/docker-calls"
cp "$test_root/docker-calls" "$test_root/docker-calls.before-retry"
if "$ghostfolio" up -d 2> "$test_root/error"; then
  echo "Ghostfolio unexpectedly retried a failed SQL import" >&2
  exit 1
fi
grep -Fq "database import state is 'failed'" "$test_root/error"
cmp -s "$test_root/docker-calls.before-retry" "$test_root/docker-calls"

# Kill only the synthetic Ghostfolio process before SQL import starts. The
# durable `ready` state permits a retry while the target directory is empty.
reset_fixture
write_prerequisites
rm -f "$runtime_root/postgres/PG_VERSION"
run_interrupted_ghostfolio() {
  local interruption=$1
  GHOSTFOLIO_INTERRUPT="$interruption" \
    bash -c 'export GHOSTFOLIO_MAIN_PID=$$; exec "$@"' \
      gnesha-ghostfolio-interruption "$ghostfolio" up -d
}
if run_interrupted_ghostfolio before-import > "$test_root/before-import.out" 2>&1; then
  echo 'synthetic Ghostfolio process was not interrupted before import' >&2
  exit 1
fi
[[ "$(cat "$runtime_root/.database-import-state")" == ready ]]
[[ ! -s "$runtime_root/postgres/PG_VERSION" ]]
[[ -s "$runtime_root/initial-database.sql" ]]
[[ ! -e "$runtime_root/.database-imported" ]]
: > "$test_root/docker-calls"
"$ghostfolio" up -d
[[ -e "$runtime_root/.database-imported" ]]
[[ -s "$runtime_root/initial-database.sql.imported" ]]
[[ "$(cat "$runtime_root/postgres/PG_VERSION")" == 17 ]]

# If the process dies after psql has consumed the dump but before the wrapper
# records success, state remains `importing` and retries are refused.
reset_fixture
write_prerequisites
rm -f "$runtime_root/postgres/PG_VERSION"
if run_interrupted_ghostfolio sql-consumed > "$test_root/sql-consumed.out" 2>&1; then
  echo 'synthetic Ghostfolio process was not interrupted in the SQL boundary' >&2
  exit 1
fi
[[ "$(cat "$runtime_root/.database-import-state")" == importing ]]
[[ -s "$test_root/psql-input" ]]
[[ -s "$runtime_root/initial-database.sql" ]]
[[ ! -e "$runtime_root/.database-imported" ]]
cp "$test_root/docker-calls" "$test_root/docker-calls.before-interrupted-retry"
if "$ghostfolio" up -d 2> "$test_root/error"; then
  echo 'Ghostfolio retried an interrupted SQL import' >&2
  exit 1
fi
grep -Fq "database import state is 'importing'" "$test_root/error"
cmp -s "$test_root/docker-calls.before-interrupted-retry" "$test_root/docker-calls"

# Uncertain and known-failed imports must stop before a database command.
for state in importing failed; do
  reset_fixture
  write_prerequisites
  printf '%s\n' "$state" > "$runtime_root/.database-import-state"
  if "$ghostfolio" up -d 2> "$test_root/error"; then
    echo "Ghostfolio unexpectedly accepted import state '$state'" >&2
    exit 1
  fi
  grep -Fq "database import state is '$state'" "$test_root/error"
  [[ ! -s "$test_root/docker-calls" ]]
done

# Missing credentials must fail preflight before any Docker call or data change.
reset_fixture
mkdir -p "$runtime_root"
: > "$test_root/docker-calls"
if "$ghostfolio" up -d 2> "$test_root/error"; then
  echo 'Ghostfolio unexpectedly accepted missing runtime credentials' >&2
  exit 1
fi
grep -Fq 'runtime secrets file is missing' "$test_root/error"
[[ ! -s "$test_root/docker-calls" ]]

# A lock for another PostgreSQL major is rejected before contacting Docker.
reset_fixture
write_prerequisites
jq '.postgresMajor = "16"' "$runtime_root/images.lock.json" > "$test_root/lock-wrong-major.json"
mv "$test_root/lock-wrong-major.json" "$runtime_root/images.lock.json"
rm -f "$runtime_root/postgres/PG_VERSION"
: > "$test_root/docker-calls"
if "$ghostfolio" up -d 2> "$test_root/error"; then
  echo 'Ghostfolio unexpectedly accepted an image lock for another PostgreSQL major' >&2
  exit 1
fi
grep -Fq 'image lock is corrupt, stale, or uses a different PostgreSQL major' "$test_root/error"
[[ ! -s "$test_root/docker-calls" ]]

# PostgreSQL readiness failures terminate at the deadline with container
# state, without calling psql or publishing import-complete state. BASH_ENV
# supplies a deterministic sleep function so the 180-second contract elapses
# immediately inside this isolated fixture.
reset_fixture
write_prerequisites
rm -f "$runtime_root/postgres/PG_VERSION"
: > "$test_root/docker-calls"
if BASH_ENV="$test_root/bash-env" GHOSTFOLIO_READY_FAIL=1 \
  "$ghostfolio" up -d > "$test_root/readiness.stdout" 2> "$test_root/readiness.stderr"; then
  echo "Ghostfolio unexpectedly continued after PostgreSQL readiness timed out" >&2
  exit 1
fi
grep -Fq 'PostgreSQL did not become ready within 180 seconds' "$test_root/readiness.stderr" || {
  echo 'PostgreSQL readiness timeout message was absent:' >&2
  cat "$test_root/readiness.stdout" "$test_root/readiness.stderr" >&2
  exit 1
}
grep -Fq 'container state: running healthy' "$test_root/readiness.stderr" || {
  echo 'PostgreSQL readiness diagnostic omitted container state:' >&2
  cat "$test_root/readiness.stdout" "$test_root/readiness.stderr" >&2
  exit 1
}
grep -Fq 'exec -T postgres pg_isready' "$test_root/docker-calls"
! grep -Fq 'exec -T postgres psql' "$test_root/docker-calls"
[[ ! -e "$runtime_root/.database-imported" ]]
[[ "$(cat "$runtime_root/.database-import-state")" == ready ]]
[[ -s "$runtime_root/initial-database.sql" ]]

# The post-import application readiness loop is separately bounded and reports
# each final service state even when Ghostfolio itself never becomes ready.
reset_fixture
write_prerequisites
rm -f "$runtime_root/postgres/PG_VERSION"
: > "$test_root/docker-calls"
if BASH_ENV="$test_root/bash-env" GHOSTFOLIO_SERVICES_UNREADY=1 \
  "$ghostfolio" up -d > "$test_root/services.stdout" 2> "$test_root/services.stderr"; then
  echo "Ghostfolio unexpectedly accepted a service that never became ready" >&2
  exit 1
fi
grep -Fq 'services did not become ready within 300 seconds' "$test_root/services.stderr" || {
  echo 'overall service readiness timeout message was absent:' >&2
  cat "$test_root/services.stdout" "$test_root/services.stderr" >&2
  exit 1
}
for service in postgres redis ghostfolio; do
  grep -Fq "$service:" "$test_root/services.stdout" || {
    echo "overall service readiness report omitted $service" >&2
    cat "$test_root/services.stdout" "$test_root/services.stderr" >&2
    exit 1
  }
done
grep -Fq 'ghostfolio: running starting' "$test_root/services.stdout"
[[ -e "$runtime_root/.database-imported" ]]
[[ -s "$runtime_root/initial-database.sql.imported" ]]
grep -Fq 'exec -T postgres psql' "$test_root/docker-calls"

# A registry failure halfway through a lock refresh must leave the last good
# image lock intact and must not publish a rollback manifest prematurely.
reset_fixture
write_prerequisites
cp "$runtime_root/images.lock.json" "$test_root/images.lock.before"
: > "$test_root/docker-calls"
if GHOSTFOLIO_PULL_FAIL=1 "$ghostfolio_pin" --refresh > "$test_root/pin.stdout" 2> "$test_root/pin.stderr"; then
  echo 'Ghostfolio pin refresh unexpectedly succeeded with an unavailable registry' >&2
  exit 1
fi
cmp -s "$test_root/images.lock.before" "$runtime_root/images.lock.json" || {
  echo 'partial Ghostfolio pin refresh changed the current image lock' >&2
  exit 1
}
[[ ! -e "$runtime_root/images.lock.json.previous.json" ]]
! grep -Fq ' image tag ' "$test_root/docker-calls"

# A complete lock refresh publishes the new digest set only after all pulls,
# retains the previous manifest, and tags each prior digest for rollback.
reset_fixture
write_prerequisites
cp "$runtime_root/images.lock.json" "$test_root/images.lock.before"
: > "$test_root/docker-calls"
"$ghostfolio_pin" --refresh > "$test_root/pin.stdout"
cmp -s "$test_root/images.lock.before" "$runtime_root/images.lock.json.previous.json" || {
  echo 'Ghostfolio pin refresh did not preserve the previous manifest' >&2
  exit 1
}
jq -e '.services | length == 3 and all(.[]; .image | test("@sha256:[0-9a-f]{64}$"))' \
  "$runtime_root/images.lock.json" >/dev/null
for service in ghostfolio postgres redis; do
  old_image=$(jq -er --arg service "$service" '.services[$service].image' "$test_root/images.lock.before")
  old_repository=${old_image%@*}
  old_repository=${old_repository%:*}
  rollback_image="$old_repository:gnesha-rollback"
  grep -Fq "image tag $old_image $rollback_image" "$test_root/docker-calls" || {
    echo "Ghostfolio pin refresh omitted the previous $service rollback tag" >&2
    exit 1
  }
done

echo "Ghostfolio import recovery stub checks passed"
