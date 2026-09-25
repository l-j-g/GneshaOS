# Fish helpers for the NixOS and Home Manager workflows. The placeholders are
# substituted by home/shell/default.nix from system-parameters.nix.

function __nix_system_generations
    command ls -dv /nix/var/nix/profiles/system-*-link 2>/dev/null
end

function nvdiff
    set -l generations (__nix_system_generations)
    if test (count $generations) -lt 2
        echo "Need at least two system generations to diff."
        return 0
    end
    nvd diff $generations[-2] $generations[-1]
end

function rebuild
    gnesha-rebuild
end

function activation-list
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
    systemctl status gnesha-nixpkgs-update.service --no-pager
    if test (systemctl is-active gnesha-nixpkgs-update.service 2>/dev/null) = activating
        echo "The candidate build is still running; update-review reports progress without waiting for its lock."
    end
    if test -L /var/lib/gnesha-update/ready
        echo "A tested update is ready. Review with update-review; apply with update-apply."
    end
end

function update-review
    gnesha-update-apply --review
end

function update-apply
    gnesha-update-apply
end

function home-rebuild
    gnesha-activation-lock nh home switch "__FLAKE_PATH__" -c "__HOME_PROFILE__" -b backup
end

function retest
    gnesha-activation-lock nh os test "__FLAKE_PATH__" -H "__HOST_NAME__"
end

function rebuild-boot
    set -l generations (__nix_system_generations)
    set -l before ""
    if test (count $generations) -gt 0
        set before $generations[-1]
    end

    gnesha-activation-lock nh os boot "__FLAKE_PATH__" -H "__HOST_NAME__"
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
    nom build "__SYSTEM_BUILD_REF__"
end

function nixeval
    if test (count $argv) -lt 1
        echo "Usage: nixeval OPTION"
        return 2
    end
    nix eval --show-trace "path:__FLAKE_PATH__#nixosConfigurations.__HOST_NAME__.config.$argv[1]"
end

function nixinspect
    if test (count $argv) -gt 0
        command nix-inspect $argv
    else
        command nix-inspect --path "__FLAKE_PATH__"
    end
end

function nixparse
    if test (count $argv) -lt 1
        echo "Usage: nixparse FILE"
        return 2
    end
    nix-instantiate --parse "$argv[1]" >/dev/null
    and echo "OK: $argv[1]"
end

function codex-nix --description "Start Codex safely in the GneshaOS repository"
    set -l repo "$HOME/.config/nix"
    if not test -d "$repo"
        echo "GneshaOS repository not found: $repo" >&2
        return 1
    end

    command codex --cd "$repo" --sandbox workspace-write --ask-for-approval never $argv
end
