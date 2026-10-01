# Refresh flake.lock in the working tree and download the closures it resolves
# to, without activating anything. Rebuild later applies these packages
# without waiting on the cache.
{
  pkgs,
  lib,
  params,
  ...
}:

let
  host = params.systemSettings;
  user = params.userSettings;
  flakePath = host.flakePath;
  stateRoot = "${user.homeDirectory}/.local/state/gnesha-lock-refresh";
  homeProfile = "${user.userName}@${host.hostName}";
  updateNetworkReady = pkgs.writeShellApplication {
    name = "gnesha-lock-refresh-network-ready";
    runtimeInputs = [ pkgs.coreutils pkgs.curl ];
    text = builtins.readFile ./update-network-ready.sh;
  };
  lockRefresh = pkgs.writeShellApplication {
    name = "gnesha-lock-refresh";
    runtimeInputs = [ pkgs.nix pkgs.jq pkgs.nvd pkgs.gnused pkgs.coreutils pkgs.util-linux ];
    text = ''
      state=${lib.escapeShellArg stateRoot}
      flake=${lib.escapeShellArg flakePath}
      # Rebuild holds this lock while it activates. Advancing flake.lock under
      # an in-flight activation would change what that activation resolves to.
      activation_lock="$HOME/.local/state/gnesha-activation/activation.lock"
      exec 9>"$state/lock"
      flock -n 9 || exit 0
      if [ -e "$activation_lock" ]; then
        exec 8>"$activation_lock"
        if ! flock -n 8; then
          echo "A rebuild is in progress; skipping lock refresh." >&2
          exit 0
        fi
      fi
      ${updateNetworkReady}/bin/gnesha-update-network-ready
      install -d -m 0700 "$state"
      candidate=$(mktemp -d "$state/refreshed.XXXXXX")
      trap 'if [ -n "$candidate" ]; then rm -rf -- "$candidate"; fi' EXIT
      before=$(jq -r .nodes.nixpkgs.locked.rev "$flake/flake.lock")
      # Advance the lock in the working tree only. Nothing is committed here;
      # rebuild and the next commit pick it up.
      nix flake update --flake "$flake"
      after=$(jq -r .nodes.nixpkgs.locked.rev "$flake/flake.lock")
      if [ "$before" = "$after" ]; then
        echo "flake.lock already current; refreshing cached counts only."
      else
        echo "nixpkgs $before -> $after"
      fi
      nix build --max-jobs 1 --cores 2 --no-link \
        "$flake#nixosConfigurations.${host.hostName}.config.system.build.toplevel"
      nix build --max-jobs 1 --cores 2 --no-link \
        "$flake#homeConfigurations.\"${homeProfile}\".activationPackage"
      system_path=$(nix eval --raw \
        "$flake#nixosConfigurations.${host.hostName}.config.system.build.toplevel")
      home_path=$(nix eval --raw \
        "$flake#homeConfigurations.\"${homeProfile}\".activationPackage")
      # Record the closures so a review can diff without re-evaluating.
      printf '%s\n' "$system_path" > "$candidate/system-path"
      printf '%s\n' "$home_path" > "$candidate/home-path"
      # Counts are the expensive part, so cache them next to the closures.
      # nvd reports one line per changed store path, which double counts
      # unwrapped variants; count only the distinct packages behind them.
      system_count=$(nvd diff /run/current-system "$system_path" \
        | grep -cE '^\[U' || echo 0)
      home_count=$(nvd diff "$HOME/.local/state/nix/profiles/home-manager" "$home_path" \
        | grep -cE '^\[U' || echo 0)
      printf '%s %s\n' "$system_count" "$home_count" > "$candidate/count"
      date --iso-8601=seconds > "$candidate/built-at"
      previous=$(readlink "$state/refreshed" || true)
      ln -sfn "$candidate" "$state/refreshed.new"
      mv -Tf "$state/refreshed.new" "$state/refreshed"
      candidate=""
      case "$previous" in "$state"/refreshed.*) rm -rf -- "$previous" ;; esac
      echo "Refreshed: $system_count system and $home_count home package updates ready."
    '';
  };
in
{
  # Download the packages flake.lock resolves to. Never activates.
  systemd.services.gnesha-lock-refresh = {
    description = "Refresh flake.lock and download the closures rebuild would use";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = user.userName;
      Group = "users";
      Environment = "HOME=${user.homeDirectory}";
      ExecStart = "${lockRefresh}/bin/gnesha-lock-refresh";
      # Downloads are background maintenance; never delay boot or rebuilds.
      Nice = 15;
      IOSchedulingClass = "idle";
      TimeoutStartSec = "6h";
      # Maintenance must not depend on a user-session proxy being available.
      UnsetEnvironment = [ "http_proxy" "https_proxy" "all_proxy" "HTTP_PROXY" "HTTPS_PROXY" "ALL_PROXY" ];
    };
  };

  systemd.timers.gnesha-lock-refresh = {
    description = "Nightly refresh of flake.lock and its closures";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 02:00:00";
      RandomizedDelaySec = "30m";
      # Runs on next boot when the machine was off overnight.
      Persistent = true;
    };
  };

  environment.systemPackages = [ lockRefresh ];
}