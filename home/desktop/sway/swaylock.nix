# Session lock: a simple GTK password prompt, with swaylock as a fallback.

{
  config,
  pkgs,
  lib,
  ...
}:

let
  v = import ../../theme/palette.nix { inherit config pkgs; };
  lockAck = pkgs.writeShellScript "gnesha-lock-ack" ''
    ${pkgs.coreutils}/bin/touch -- "$GNESHA_LOCK_ACK_FILE"
  '';
  lock = pkgs.writeShellApplication {
    name = "gnesha-lock";
    runtimeInputs = [
      pkgs.util-linux
      pkgs.coreutils
      pkgs.dbus
      pkgs.gtklock
      pkgs.swaylock
    ];
    text = ''
      # shellcheck disable=SC1091
      source ${../../shell/lock-readiness.sh}
      gnesha_lock_acquire
    '';
  };
  lockAndSuspend = pkgs.writeShellApplication {
    name = "gnesha-lock-and-suspend";
    runtimeInputs = [
      pkgs.util-linux
      pkgs.coreutils
      pkgs.dbus
      pkgs.gtklock
      pkgs.swaylock
      pkgs.acpi
      pkgs.systemd
    ];
    text = ''
      # shellcheck disable=SC1091
      source ${../../shell/lock-readiness.sh}
      gnesha_lock_and_suspend "$@"
    '';
  };
in
{
  home.packages = [
    lock
    lockAndSuspend
    pkgs.gtklock
  ];
  xdg.configFile."gtklock/config.ini".text = ''
    [main]
    gtk-theme=${config.gtk.theme.name}
    style=${config.xdg.configHome}/gtklock/style.css
    time-format=%H:%M
    date-format=%a, %d %b
    lock-command=${lockAck}
  '';
  xdg.configFile."gtklock/style.css".text = ''
    window {
      background-image: none;
      background-color: ${v.bg};
      color: ${v.foreground};
      font-family: monospace;
      font-size: 16px;
    }
    #window-box {
      background-color: ${v.bg};
      border: 1px solid ${v.accent};
      border-radius: 0;
      padding: 28px;
    }
    entry { border-radius: 0; }
    button { border-radius: 0; }
  '';
  wayland.windowManager.sway.extraConfig = ''
    bindswitch --locked lid:on exec ${lockAndSuspend}/bin/gnesha-lock-and-suspend --lid
  '';

  # Retain a known fallback during migration to the new locker.
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock;
    settings = {
      color = v.bg;
      "inside-color" = v.bg;
      "ring-color" = v.accentDark;
      "key-hl-color" = v.accent;
      "bs-hl-color" = v.critical;
      "line-color" = v.bg;
      "inside-clear-color" = v.bg;
      "ring-clear-color" = v.accent;
      "inside-ver-color" = v.bg;
      "ring-ver-color" = v.accent;
      "inside-wrong-color" = v.bg;
      "ring-wrong-color" = v.critical;
      "text-clear-color" = v.accent;
      "text-ver-color" = v.accent;
      "text-wrong-color" = v.critical;
    };
  };
}
