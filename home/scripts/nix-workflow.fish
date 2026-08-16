# Fish helpers for the NixOS workflow. The three placeholders are substituted
# by home/shell.nix from params.nix.

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
    set -l generations (__nix_system_generations)
    set -l before ""
    if test (count $generations) -gt 0
        set before $generations[-1]
    end

    nh os switch "__FLAKE_PATH__" -H "__HOST_NAME__"
    if test $status -ne 0
        return 1
    end

    set generations (__nix_system_generations)
    if test -n "$before"; and test (count $generations) -gt 0
        set -l after $generations[-1]
        if test "$before" != "$after"
            nvd diff "$before" "$after"
        else
            echo "No new system generation; nothing to diff."
        end
    else
        nvdiff
    end
end

function retest
    nh os test "__FLAKE_PATH__" -H "__HOST_NAME__"
end

function rebuild-boot
    set -l generations (__nix_system_generations)
    set -l before ""
    if test (count $generations) -gt 0
        set before $generations[-1]
    end

    nh os boot "__FLAKE_PATH__" -H "__HOST_NAME__"
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

function nixparse
    if test (count $argv) -lt 1
        echo "Usage: nixparse FILE"
        return 2
    end
    nix-instantiate --parse "$argv[1]" >/dev/null
    and echo "OK: $argv[1]"
end

function codex-nix
    cd ~/.config/nix; or return 1
    codex
end
