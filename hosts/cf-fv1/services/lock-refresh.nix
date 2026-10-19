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
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
    ];
    text = builtins.readFile ./update-network-ready.sh;
  };
  lockRefresh = pkgs.writeShellApplication {
    name = "gnesha-lock-refresh";
    runtimeInputs = [
      pkgs.nix
      pkgs.jq
      pkgs.nvd
      pkgs.libnotify
      pkgs.gawk
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      set -- ${lib.escapeShellArg stateRoot} ${lib.escapeShellArg flakePath} \
        ${lib.escapeShellArg host.hostName} ${lib.escapeShellArg homeProfile} \
        ${updateNetworkReady}/bin/gnesha-update-network-ready "$@"
    ''
    + builtins.readFile ./scripts/lock-refresh.sh;
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
      UnsetEnvironment = [
        "http_proxy"
        "https_proxy"
        "all_proxy"
        "HTTP_PROXY"
        "HTTPS_PROXY"
        "ALL_PROXY"
      ];
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
