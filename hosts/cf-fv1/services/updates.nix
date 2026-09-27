{ pkgs, lib, params, ... }:

let
  proxy = params.systemSettings.systemProxy or { enable = false; };
  proxyUrl = "http://${proxy.host}:${toString proxy.port}";
  updateState = "/var/lib/gnesha-update";
  activationStateLib = ../../../home/shell/activation-state.sh;
  updateReviewLib = ../../../home/shell/update-review.sh;
  activationStateRoot = "${params.userSettings.homeDirectory}/.local/state/gnesha-activation";
  updateBuild = pkgs.writeShellApplication {
    name = "gnesha-update-build";
    runtimeInputs = [ pkgs.nix pkgs.git pkgs.jq pkgs.coreutils pkgs.util-linux ];
    text = ''
      state=${lib.escapeShellArg updateState}
      exec 9>"$state/lock"
      flock -n 9 || exit 0
      candidate=$(mktemp -d "$state/candidate.XXXXXX")
      trap 'if [ -n "$candidate" ]; then rm -rf -- "$candidate"; fi' EXIT
      snapshot=$(nix flake metadata --json --no-write-lock-file ${lib.escapeShellArg params.systemSettings.flakePath} | jq -er .path)
      cp "$snapshot/flake.lock" "$candidate/base.lock"
      cp -R "$snapshot" "$candidate/source"
      chmod -R u+w "$candidate/source"
      # Update only the candidate. The working tree and live machine stay put.
      nix flake update nixpkgs --flake "$candidate/source"
      nix flake check --no-build --no-write-lock-file "$candidate/source"
      nix build --max-jobs 1 --cores 2 --no-write-lock-file \
        --out-link "$candidate/system" \
        "$candidate/source#nixosConfigurations.${params.systemSettings.hostName}.config.system.build.toplevel"
      nix build --max-jobs 1 --cores 2 --no-write-lock-file \
        --out-link "$candidate/home" \
        "$candidate/source#homeConfigurations.\"${params.userSettings.userName}@${params.systemSettings.hostName}\".activationPackage"
      date --iso-8601=seconds > "$candidate/built-at"
      previous=$(readlink "$state/ready" || true)
      ln -sfn "$candidate" "$state/ready.new"
      mv -Tf "$state/ready.new" "$state/ready"
      candidate=""
      # Keep one ready candidate; remove only directories created by this job.
      case "$previous" in "$state"/candidate.*) rm -rf -- "$previous" ;; esac
      echo "Update built successfully. Review with update-review; apply with update-apply."
    '';
  };
  updateApply = pkgs.writeShellApplication {
    name = "gnesha-update-apply";
    runtimeInputs = [ pkgs.nix pkgs.nh pkgs.nvd pkgs.jq pkgs.coreutils pkgs.diffutils pkgs.util-linux pkgs.gnused ];
    text = ''
      activation_state_root=${lib.escapeShellArg activationStateRoot}
      # shellcheck source=${activationStateLib}
      activation_id=
      activation_dir=
      activation_phase=
      activation_new_system=
      activation_new_home=
      activation_old_lock=
      activation_new_lock=
      : "$activation_state_root" "$activation_phase" "$activation_new_system" "$activation_new_home"
      # shellcheck disable=SC1091
      source ${activationStateLib}
      # shellcheck disable=SC1091
      source ${updateReviewLib}
      state=${lib.escapeShellArg updateState}
      repo=${lib.escapeShellArg params.systemSettings.flakePath}
      if [ "''${1:-}" = --review ]; then
        update_review "$state" "$repo" /run/current-system
        exit "$?"
      fi
      exec 8>"$state/lock"
      flock 8
      if [ ! -L "$state/ready" ]; then
        echo "No completed update is ready. Check systemctl status gnesha-nixpkgs-update." >&2
        exit 1
      fi
      ready=$(readlink -f "$state/ready")
      echo "Candidate built at $(cat "$ready/built-at")"
      diff -u "$repo/flake.lock" "$ready/source/flake.lock" || [ "$?" -eq 1 ]
      nvd diff /run/current-system "$ready/system"
      if [ "$#" -ne 0 ]; then echo "Usage: gnesha-update-apply [--review]" >&2; exit 2; fi
      current=$("''${NIX_COMMAND:-nix}" flake metadata --json --no-write-lock-file "$repo" | jq -er .path)
      if ! diff -qr --exclude=flake.lock "$current" "$ready/source" >/dev/null ||
        { ! cmp -s "$current/flake.lock" "$ready/base.lock" &&
          ! cmp -s "$current/flake.lock" "$ready/source/flake.lock"; }; then
        echo "Configuration changed since this candidate was built; refusing to activate stale settings." >&2
        echo "Run sudo systemctl start gnesha-nixpkgs-update, then review the new candidate." >&2
        exit 1
      fi
      # Explicit update-apply accepts the reviewed lock file and exact closures.
      candidateSnapshot=$("''${NIX_COMMAND:-nix}" flake metadata --json --no-write-lock-file "$ready/source" | jq -er .path)
      activation_lock
      if ! activation_require_capacity; then
        activation_unlock
        exit 1
      fi
      activation_create update "$candidateSnapshot" "$repo"
      activation_unlock
      activation_old_lock="$activation_dir/old.lock"
      activation_new_lock="$activation_dir/new.lock"
      if ! cp -- "$repo/flake.lock" "$activation_old_lock" ||
        ! cp -- "$ready/source/flake.lock" "$activation_new_lock"; then
        activation_set_phase failed_preparation
        echo "Could not preserve the current and candidate lock files; attempt $activation_id was retained." >&2
        exit 1
      fi
      if ! cmp -s "$activation_old_lock" "$ready/base.lock" &&
        ! cmp -s "$activation_old_lock" "$activation_new_lock"; then
        activation_set_phase blocked_lock_mismatch
        echo "Repository flake.lock matches neither the candidate base nor candidate lock; leaving it untouched. Attempt $activation_id was retained." >&2
        exit 1
      fi
      chmod 600 -- "$activation_old_lock" "$activation_new_lock"
      systemClosure=$(readlink -f "$ready/system")
      homeClosure=$(readlink -f "$ready/home")
      ln -s -- "$systemClosure" "$activation_dir/system"
      ln -s -- "$homeClosure" "$activation_dir/home"
      activation_new_system="$systemClosure"
      activation_new_home="$homeClosure"
      activation_set_phase candidate_ready

      activation_lock
      if ! activation_update_accept_lock; then exit 1; fi
      if ! activation_apply_pair false true; then
        exit 1
      fi
    '';
  };
in
{
  # Prepare updates on AC power without editing the working tree or activating.
  systemd.services.gnesha-nixpkgs-update = {
    description = "Prepare and build a NixOS and Home Manager update";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionACPower = true;
    serviceConfig = {
      Type = "oneshot";
      User = params.userSettings.userName;
      Group = "users";
      Environment = "HOME=${params.userSettings.homeDirectory}";
      StateDirectory = "gnesha-update";
      StateDirectoryMode = "0700";
      ExecStart = "${updateBuild}/bin/gnesha-update-build";
      Nice = 15;
      IOSchedulingClass = "idle";
      TimeoutStartSec = "6h";
      # Maintenance must not depend on a user-session proxy being available.
      UnsetEnvironment = [ "http_proxy" "https_proxy" "all_proxy" "HTTP_PROXY" "HTTPS_PROXY" "ALL_PROXY" ];
    };
  };

  systemd.timers.gnesha-nixpkgs-update = {
    description = "Prepare a daily background update";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 05:30:00";
      RandomizedDelaySec = "30m";
      Persistent = true;
    };
  };

  environment.systemPackages = [ updateApply ];
}
