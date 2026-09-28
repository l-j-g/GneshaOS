#!/usr/bin/env bash
set -Eeuo pipefail

ghostfolio=${1:?usage: ghostfolio-import-recovery-stubs.sh /path/to/ghostfolio /build/test-root}
test_root=${2:?usage: ghostfolio-import-recovery-stubs.sh /path/to/ghostfolio /build/test-root}
runtime_root="$test_root/ghostfolio"

# This fixture is only safe in its dedicated Nix build sandbox directory.
[[ "$test_root" == /build/gnesha-ghostfolio-import-check ]] || {
  echo "refusing to use a runtime root outside the dedicated build fixture" >&2
  exit 2
}
[[ -x "$ghostfolio" ]] || {
  echo "generated Ghostfolio command is missing: $ghostfolio" >&2
  exit 2
}

reset_fixture() {
  [[ -d "$runtime_root" && ! -L "$runtime_root" ]] || return 0
  rm -rf -- "$runtime_root/postgres"
  rm -f -- \
    "$runtime_root/.database-imported" \
    "$runtime_root/.database-import-state" \
    "$runtime_root/initial-database.sql" \
    "$runtime_root/initial-database.sql.imported" \
    "$runtime_root/images.lock.json" \
    "$runtime_root/secrets.env" \
    "$test_root/docker-calls" \
    "$test_root/docker-calls.before-retry" \
    "$test_root/psql-input"
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
"$ghostfolio" up -d
[[ -e "$runtime_root/.database-imported" ]]
[[ ! -e "$runtime_root/.database-import-state" ]]
[[ ! -e "$runtime_root/initial-database.sql" ]]
[[ -s "$runtime_root/initial-database.sql.imported" ]]
grep -Fq 'exec -T postgres pg_isready' "$test_root/docker-calls"
grep -Fq 'exec -T postgres psql' "$test_root/docker-calls"
grep -Fq 'SELECT 1;' "$test_root/psql-input"

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

# PostgreSQL readiness failures terminate at the deadline with container
# state, without calling psql or publishing import-complete state. BASH_ENV
# supplies a deterministic sleep function so the 180-second contract elapses
# immediately inside this isolated fixture.
reset_fixture
write_prerequisites
rm -f "$runtime_root/postgres/PG_VERSION"
cat > "$test_root/bash-env" <<'BASH_ENV'
sleep() {
  local delay=${1%s}
  SECONDS=$((SECONDS + delay))
}
BASH_ENV
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

echo "Ghostfolio import recovery stub checks passed"
