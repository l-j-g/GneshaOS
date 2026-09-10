#!/usr/bin/env sh
# once.sh <command...> — run a command but only one instance at a time.
mkdir -p "$HOME/.local/state"
exec flock -n "$HOME/.local/state/once.lock" "$@"
