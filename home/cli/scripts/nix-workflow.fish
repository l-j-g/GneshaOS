# Fish helpers for Nix workflows. Home Manager exports the configured flake,
# host, profile, and build reference as GNESHA_* session variables.

function __nix_system_generations
    command ls -dv /nix/var/nix/profiles/system-*-link 2>/dev/null
end

function nvdiff
    if test (count $argv) -ne 0
        echo "Usage: nvdiff"
        return 2
    end
    set -l generations (__nix_system_generations)
    if test (count $generations) -lt 2
        echo "Need at least two system generations to diff."
        return 0
    end
    nvd diff $generations[-2] $generations[-1]
end

function rebuild
    gnesha-rebuild $argv
end

function activation-list
    if test (count $argv) -ne 0
        echo "Usage: activation-list"
        return 2
    end
    gnesha-rebuild --list
end

function activation-resume
    if test (count $argv) -ne 1
        echo "Usage: activation-resume ATTEMPT_ID"
        return 2
    end
    gnesha-rebuild --resume $argv[1]
end

function activation-discard
    if test (count $argv) -ne 1
        echo "Usage: activation-discard ATTEMPT_ID"
        return 2
    end
    gnesha-rebuild --discard $argv[1]
end

function update-status
    if test (count $argv) -ne 0
        echo "Usage: update-status"
        return 2
    end
    systemctl status gnesha-lock-refresh.service --no-pager
    if test (systemctl is-active gnesha-lock-refresh.service 2>/dev/null) = activating
        echo "Refreshing flake.lock and downloading packages. This does not activate anything."
    end
    if test -d "$HOME/.local/state/gnesha-lock-refresh/refreshed"
        echo "Packages are downloaded and will be applied on the next rebuild."
    end
end

function update-review
    if test (count $argv) -ne 0
        echo "Usage: update-review"
        return 2
    end
    updates-pending status
end

function home-rebuild
    if test (count $argv) -ne 0
        echo "Usage: home-rebuild"
        return 2
    end
    gnesha-activation-lock nh home switch "$GNESHA_FLAKE_PATH" -c "$GNESHA_HOME_PROFILE" -b backup
end

function retest
    if test (count $argv) -ne 0
        echo "Usage: retest"
        return 2
    end
    gnesha-activation-lock nh os test "$GNESHA_FLAKE_PATH" -H "$GNESHA_HOST_NAME"
end

function rebuild-boot
    if test (count $argv) -ne 0
        echo "Usage: rebuild-boot"
        return 2
    end
    set -l generations (__nix_system_generations)
    set -l before ""
    if test (count $generations) -gt 0
        set before $generations[-1]
    end

    gnesha-activation-lock nh os boot "$GNESHA_FLAKE_PATH" -H "$GNESHA_HOST_NAME"
    if test $status -ne 0
        return 1
    end

    set generations (__nix_system_generations)
    if test -n "$before"; and test (count $generations) -gt 0
        set -l after $generations[-1]
        if test "$before" != "$after"
            nvd diff "$before" "$after"
        end
    end
end

function nixbuild
    nom build "$GNESHA_SYSTEM_BUILD_REF" $argv
end

function nixeval
    if test (count $argv) -ne 1
        echo "Usage: nixeval OPTION"
        return 2
    end
    nix eval --show-trace "path:$GNESHA_FLAKE_PATH#nixosConfigurations.$GNESHA_HOST_NAME.config.$argv[1]"
end

function nixinspect
    if test (count $argv) -gt 0
        command nix-inspect $argv
    else
        command nix-inspect --path "$GNESHA_FLAKE_PATH"
    end
end

function nixparse
    if test (count $argv) -ne 1
        echo "Usage: nixparse FILE"
        return 2
    end
    nix-instantiate --parse "$argv[1]" >/dev/null
    and echo "OK: $argv[1]"
end

function codex-nix --description "Start Codex with full access in the GneshaOS repository"
    set -l repo "$GNESHA_FLAKE_PATH"
    if not test -d "$repo"
        echo "GneshaOS repository not found: $repo" >&2
        return 1
    end

    command codex --cd "$repo" --sandbox danger-full-access --ask-for-approval never $argv
end
