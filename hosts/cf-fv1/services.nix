{ pkgs, lib, params, ... }:

let
  proxy = params.systemSettings.systemProxy or { enable = false; };
  proxyUrl = "http://${proxy.host}:${toString proxy.port}";
  updateState = "/var/lib/gnesha-update";
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
    runtimeInputs = [ pkgs.nix pkgs.nh pkgs.nvd pkgs.jq pkgs.coreutils pkgs.diffutils pkgs.util-linux ];
    text = ''
      state=${lib.escapeShellArg updateState}
      repo=${lib.escapeShellArg params.systemSettings.flakePath}
      if [ ! -L "$state/ready" ]; then
        echo "No completed update is ready. Check systemctl status gnesha-nixpkgs-update." >&2
        exit 1
      fi
      exec 9>"$state/lock"
      flock 9
      ready=$(readlink -f "$state/ready")
      echo "Candidate built at $(cat "$ready/built-at")"
      diff -u "$repo/flake.lock" "$ready/source/flake.lock" || [ "$?" -eq 1 ]
      nvd diff /run/current-system "$ready/system"
      if [ "''${1:-}" = --review ]; then exit 0; fi
      if [ "$#" -ne 0 ]; then echo "Usage: gnesha-update-apply [--review]" >&2; exit 2; fi
      current=$(nix flake metadata --json --no-write-lock-file "$repo" | jq -er .path)
      if ! diff -qr --exclude=flake.lock "$current" "$ready/source" >/dev/null ||
        { ! cmp -s "$current/flake.lock" "$ready/base.lock" &&
          ! cmp -s "$current/flake.lock" "$ready/source/flake.lock"; }; then
        echo "Configuration changed since this candidate was built; refusing to activate stale settings." >&2
        echo "Run sudo systemctl start gnesha-nixpkgs-update, then review the new candidate." >&2
        exit 1
      fi
      # Explicit update-apply accepts the reviewed lock file and exact closures.
      lockTemp=$(mktemp "$repo/.flake.lock.XXXXXX")
      trap 'rm -f -- "$lockTemp"' EXIT
      cp "$ready/source/flake.lock" "$lockTemp"
      chmod 644 "$lockTemp"
      mv -f "$lockTemp" "$repo/flake.lock"
      nh os switch "$ready/system"
      nh home switch "$ready/home" -b backup
    '';
  };
in
{
  networking.hostName = params.systemSettings.hostName;
  networking.networkmanager.enable = true;

  # Optional host HTTP proxy, independent of the Docker Gluetun proxy.
  # Native AirVPN WireGuard routing does not require HTTP proxy variables.
  networking.proxy = lib.mkIf proxy.enable {
    httpProxy = proxyUrl;
    httpsProxy = proxyUrl;
    noProxy = proxy.noProxy;
  };

  # Builds must remain available while the optional application proxy is down.
  systemd.services.nix-daemon.serviceConfig.UnsetEnvironment = [
    "http_proxy" "https_proxy" "all_proxy"
    "HTTP_PROXY" "HTTPS_PROXY" "ALL_PROXY"
  ];

  # Local time = system timezone from the top-level params (should match the
  # wlsunset coordinates).
  time.timeZone = params.systemSettings.timeZone;

  # macOS SMB share for the exFAT media volume.
  # Access is limited to the home LAN; authentication uses Samba's
  # separate password database for the user from the top-level params.
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = params.systemSettings.hostName;
        security = "user";
        "map to guest" = "never";
        "server min protocol" = "SMB2";
        # SMB is LAN-only: set "hosts allow" to your subnet + loopback,
        # and deny everything else.
        "hosts allow" = "127. 192.";
        "hosts deny" = "0.0.0.0/0";
      };
      media = {
        path = "/media";
        browseable = "yes";
        "read only" = "no";
        "valid users" = params.userSettings.userName;
        "force user" = params.userSettings.userName;
        "create mask" = "0664";
        "directory mask" = "0775";
      };
    };
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd sway";
      user = "greeter";
    };
  };

  hardware.bluetooth.enable = true;

  # Enable the NixOS Steam integration (runtime libraries, udev rules, and
  # the supported launcher setup) for the gaming packages managed in Home
  # Manager.
  programs.steam.enable = true;

  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  services.libinput.enable = true;

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

  # Make login shell (fish) available system-wide and link portal files
  # when Home Manager runs with useUserPackages.
  programs.fish.enable = true;
  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];

  environment.systemPackages = with pkgs; [
    updateApply
    vim
    git
    curl
    wget
    file
    pciutils
    usbutils
    libinput
    rsync
    gvfs
    libmtp
    udisks2
    lm_sensors
    nh
    brightnessctl
    acpi
    powertop
    docker-compose
    libnotify
    # Ghostty sets TERM=xterm-ghostty; make that terminfo entry available
    # system-wide to tmux and programs launched outside Home Manager's shell.
    ghostty.terminfo
  ];
}
