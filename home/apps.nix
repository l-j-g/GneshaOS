# General-purpose desktop / media apps that are not part of the Sway
# compositor setup itself.

{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  lfPreviewer = ./desktop/scripts/lf/preview;
in
{
  home.packages =
    with pkgs;
    [
      tor-browser
      discord
      firefox
      imv
      mpv
      fastfetch
      opencode
      codex
      uv
      ueberzugpp
    ]
    ++ [
      inputs.mcp-nixos.packages.${pkgs.system}.default
    ];

  # Keep the Hermes UI on this machine while its agent backend remains on the
  # MacBook. The SSH alias is defined in ~/.ssh/config; the tunnel forwards
  # the MacBook's loopback-only Hermes dashboard to a local port.
  systemd.user.services.hermes-mac-tunnel = {
    Unit = {
      Description = "SSH tunnel to the MacBook Hermes backend";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${pkgs.openssh}/bin/ssh -N -T -o BatchMode=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -L 19119:127.0.0.1:9119 mac";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  xdg.desktopEntries.hermes-mac = {
    name = "Hermes (MacBook)";
    comment = "Open the Hermes Agent running on the MacBook";
    exec = "${pkgs.firefox}/bin/firefox --new-window http://127.0.0.1:19119";
    terminal = false;
    categories = [ "Network" "Office" ];
  };

  # Optional local opencode config. Only installed when the file exists next
  # to the repo (it is machine-specific and intentionally not tracked), so a
  # fresh clone evaluates without it. Copy your own into place if you use it.
  # LF's image layer and wrapper live outside the Nix module so the preview
  # protocol stays readable and independently testable.
  xdg.configFile = (lib.optionalAttrs (builtins.pathExists ../opencode.json) {
    "opencode/opencode.jsonc".source = ../opencode.json;
  }) // {
    "lf/cleaner" = {
      source = ./desktop/scripts/lf/cleaner;
      executable = true;
    };
  };
  home.file.".local/bin/lf-image" = {
    source = ./desktop/scripts/lf/lf-image;
    executable = true;
  };
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

  # Open files from nnn with nvim (text) / imv/mpv (media).
  home.sessionVariables = {
    NNN_OPENER = "nnn-opener";
    # preview-tui falls back to xterm otherwise; use the existing Foot server.
    NNN_TERMINAL = "${pkgs.foot}/bin/footclient";
    # Render image previews in Foot (and in tmux when used there).
    NNN_PREVIEWIMGPROG = "chafa";
  };

  services.udiskie = {
    enable = true;
    settings = {
      automount = true;
      notify = true;
    };
  };

  programs.nnn = {
    enable = true;
    enableFishIntegration = true;
    extraPackages = with pkgs; [
      chafa
      ffmpegthumbnailer
      less
      mediainfo
      poppler-utils
      tree
      unzip
    ];
    plugins = {
      # The nnn package already ships the official plugins.
      src = "${pkgs.nnn}/share/plugins";
      mappings.p = "preview-tui";
    };
    # quitcd is off: its `n` function would clash with the `n` = nvim abbr.
    options = [
      "H" # show hidden files by default
      "S" # persistent sessions
    ];
  };

  programs.lf = {
    enable = true;
    previewer.source = lfPreviewer;
    settings.cleaner = "${config.xdg.configHome}/lf/cleaner";
    commands = {
      # Reset the preview position whenever the selected file changes.
      on-select = "set user_preview_offset 1";
      scroll-preview = ''&{{
        offset=$((lf_user_preview_offset + $1))
        [ "$offset" -lt 1 ] && offset=1
        lf -remote "send $id :set user_preview_offset $offset; set preview true"
      }}'';
    };
    keybindings = {
      "<a-j>" = "scroll-preview 5";
      "<a-k>" = "scroll-preview -5";
    };
    extraConfig = ''
      set user_preview_offset 1
    '';
    settings = {
      hidden = true;
      number = true;
      ratios = [
        1
        2
        3
      ];
    };
  };

  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    mouse = true;
    keyMode = "vi";
    escapeTime = 0;
    focusEvents = true;
    historyLimit = 50000;
    extraConfig = ''
      set -g renumber-windows on
      set -g set-clipboard on
      set -as terminal-features ",*:RGB"
    '';
  };
}
