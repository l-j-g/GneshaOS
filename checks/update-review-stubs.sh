#!/usr/bin/env bash
set -euo pipefail

review_helper="$1"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin" "$work/repo" "$work/state"
printf '#!%s\n' "$(command -v bash)" > "$work/bin/diff"
cat >> "$work/bin/diff" <<'EOF'
printf 'diff %s\n' "$*" >> "$TOOL_LOG"
EOF
printf '#!%s\n' "$(command -v bash)" > "$work/bin/nvd"
cat >> "$work/bin/nvd" <<'EOF'
printf 'nvd %s\n' "$*" >> "$TOOL_LOG"
EOF
chmod +x "$work/bin/diff" "$work/bin/nvd"
export PATH="$work/bin:$PATH"
export TOOL_LOG="$work/tools.log"
source "$review_helper"

# A held update lock must make review return immediately without tools.
exec 9>"$work/state/lock"
flock -n 9
if ! update_review "$work/state" "$work/repo" "$work/current-system"; then
  echo "review failed while the update lock was held" >&2
  exit 1
fi
[[ ! -e "$TOOL_LOG" ]]
flock -u 9
exec 9>&-

# Missing ready candidate must stop before diff or nvd.
if update_review "$work/state" "$work/repo" "$work/current-system"; then
  echo "review unexpectedly succeeded without a ready candidate" >&2
  exit 1
fi
[[ ! -e "$TOOL_LOG" ]]

# A valid candidate is reviewed read-only and leaves the repository lock intact.
mkdir -p "$work/candidate/source" "$work/candidate/system"
printf 'base-lock\n' > "$work/repo/flake.lock"
cp "$work/repo/flake.lock" "$work/flake.lock.before"
printf 'candidate-lock\n' > "$work/candidate/source/flake.lock"
printf '2026-09-27T00:00:00Z\n' > "$work/candidate/built-at"
ln -s "$work/candidate" "$work/state/ready"
update_review "$work/state" "$work/repo" "$work/current-system"
cmp -s "$work/repo/flake.lock" "$work/flake.lock.before"
printf 'diff -u %s/repo/flake.lock %s/candidate/source/flake.lock\nnvd diff %s/current-system %s/candidate/system\n' \
  "$work" "$work" "$work" "$work" > "$work/expected.log"
cmp -s "$TOOL_LOG" "$work/expected.log"

echo "update-review helper stub checks passed"
