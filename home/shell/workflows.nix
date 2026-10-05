{
  lib,
  pkgs,
  params,
  variables,
  ...
}:

let
  flakePath = params.systemSettings.flakePath;
  hostName = params.systemSettings.hostName;
  homeProfile = "${params.userSettings.userName}@${hostName}";
  systemBuildRef = "${flakePath}#nixosConfigurations.${hostName}.config.system.build.toplevel";
  activationStateLib = ./activation-state.sh;
  activationLock = pkgs.writeShellApplication {
    name = "gnesha-activation-lock";
    runtimeInputs = [ pkgs.coreutils pkgs.util-linux ];
    text = ''
      activation_state_root=${lib.escapeShellArg "${params.userSettings.homeDirectory}/.local/state/gnesha-activation"}
      activation_lock_file="$activation_state_root/activation.lock"
      # shellcheck disable=SC1091
      source ${activationStateLib}
      if [[ "$#" -eq 0 ]]; then
        echo "Usage: gnesha-activation-lock COMMAND [ARG ...]" >&2
        exit 2
      fi
      activation_init
      exec flock -x "$activation_lock_file" "$@"
    '';
  };
  buildMonitor = pkgs.writeShellApplication {
    name = "gnesha-build-monitor";
    runtimeInputs = [ pkgs.nix pkgs.nix-output-monitor pkgs.jq pkgs.coreutils ];
    text = builtins.readFile ./build-monitor;
  };
  rebuild = pkgs.writeShellApplication {
    name = "gnesha-rebuild";
    runtimeInputs = [ buildMonitor pkgs.nix pkgs.nh pkgs.nix-output-monitor pkgs.nvd pkgs.jq pkgs.coreutils pkgs.diffutils pkgs.util-linux pkgs.gnused ];
    text = ''
      activation_state_root=${lib.escapeShellArg "${params.userSettings.homeDirectory}/.local/state/gnesha-activation"}
      : "$activation_state_root"
      # shellcheck disable=SC1091
      source ${activationStateLib}
      flakePath=${lib.escapeShellArg flakePath}
      hostName=${lib.escapeShellArg hostName}
      homeProfile=${lib.escapeShellArg homeProfile}
      ${builtins.readFile ./gnesha-rebuild}
    '';
  };
  showPublicKey = pkgs.writeShellApplication {
    name = "pubkey";
    runtimeInputs = [ pkgs.coreutils pkgs.wl-clipboard pkgs.xclip ];
    text = ''
      keyFile=${lib.escapeShellArg variables.publicKeyFile}
      if [[ ! -r "$keyFile" ]]; then
        echo "pubkey: cannot read $keyFile" >&2
        exit 1
      fi

      cat -- "$keyFile"
      if [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
        wl-copy < "$keyFile"
        echo "Public key copied to clipboard." >&2
      elif [[ -n "''${DISPLAY:-}" ]]; then
        xclip -selection clipboard < "$keyFile"
        echo "Public key copied to clipboard." >&2
      else
        echo "No graphical clipboard is available; printed only." >&2
      fi
    '';
  };
  decryptClipboard = pkgs.writeShellApplication {
    name = "declypt";
    runtimeInputs = [ pkgs.gnupg pkgs.wl-clipboard pkgs.xclip ];
    text = ''
      if [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
        wl-paste --no-newline | gpg --decrypt
      elif [[ -n "''${DISPLAY:-}" ]]; then
        xclip -o -selection clipboard | gpg --decrypt
      else
        echo "declypt: no graphical clipboard is available" >&2
        exit 1
      fi
    '';
  };
in
{
  home.packages = [ rebuild activationLock showPublicKey decryptClipboard pkgs.nh pkgs.nvd pkgs.nix-output-monitor pkgs.nix-inspect ];
  home.sessionVariables = {
    GNESHA_FLAKE_PATH = flakePath;
    GNESHA_HOST_NAME = hostName;
    GNESHA_HOME_PROFILE = homeProfile;
    GNESHA_SYSTEM_BUILD_REF = systemBuildRef;
  };

  # Build/update helpers and intentionally raw activation fallbacks.
  programs.fish.shellAliases = {
    nf = "nixfmt";
    nfcheck = "nixfmt --check";
    nixcheck = "nix flake check --show-trace ${lib.escapeShellArg flakePath}";
    nixgc = "sudo nix-collect-garbage -d";
    home-rebuild-raw = "gnesha-activation-lock nh home switch ${lib.escapeShellArg flakePath} -c ${lib.escapeShellArg homeProfile} -b backup";
    rebuild-raw = "gnesha-activation-lock sudo nixos-rebuild switch --flake ${lib.escapeShellArg "${flakePath}#${hostName}"}";
    retest-raw = "gnesha-activation-lock sudo nixos-rebuild test --flake ${lib.escapeShellArg "${flakePath}#${hostName}"}";
    rebuild-boot-raw = "gnesha-activation-lock sudo nixos-rebuild boot --flake ${lib.escapeShellArg "${flakePath}#${hostName}"}";
  };
  programs.fish.interactiveShellInit = builtins.readFile ./nix-workflow.fish;
  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;
}
