#!/usr/bin/env fish

set -l workflow $argv[1]
if test -z "$workflow"; or not test -r "$workflow"
    echo "usage: nix-workflow-status.fish WORKFLOW" >&2
    exit 2
end

set -l work (mktemp -d)
set -gx TOOL_LOG "$work/systemctl.log"
set -gx SYSTEMCTL_ACTIVE_STATE inactive

function systemctl
    printf '%s\n' (string join ' ' -- $argv) >> "$TOOL_LOG"
    switch "$argv[1]"
        case status
            echo 'stub status output'
        case is-active
            echo "$SYSTEMCTL_ACTIVE_STATE"
    end
end

source "$workflow"

update-status > "$work/inactive-output"
if not grep -Fxq 'status gnesha-nixpkgs-update.service --no-pager' "$TOOL_LOG"
    echo "update-status did not request systemctl status" >&2
    exit 1
end
if not grep -Fq 'stub status output' "$work/inactive-output"
    echo "update-status did not show the status command output" >&2
    exit 1
end
if not grep -Fxq 'is-active gnesha-nixpkgs-update.service' "$TOOL_LOG"
    echo "update-status did not inspect the service state" >&2
    exit 1
end

: > "$TOOL_LOG"
set -gx SYSTEMCTL_ACTIVE_STATE activating
update-status > "$work/activating-output"
if not grep -Fq 'candidate build is still running' "$work/activating-output"
    echo "update-status omitted its in-progress guidance" >&2
    exit 1
end
if not grep -Fxq 'status gnesha-nixpkgs-update.service --no-pager' "$TOOL_LOG"
    echo "update-status omitted systemctl status while activating" >&2
    exit 1
end

rm -rf -- "$work"
echo 'nix workflow status fixture passed'
