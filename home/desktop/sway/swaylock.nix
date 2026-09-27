# Session lock: a simple GTK password prompt, with swaylock as a fallback.

{
  config,
  pkgs,
  lib,
  ...
}:

let
  v = import ../../theme/palette.nix { inherit config pkgs; };
  lock = pkgs.writeShellApplication {
    name = "gnesha-lock";
    runtimeInputs = [ pkgs.util-linux pkgs.procps pkgs.dbus pkgs.gtklock pkgs.swaylock ];
    text = ''
      # Serialize concurrent lid/idle/sleep requests until the compositor has
      # acknowledged the lock. --close keeps the daemon from holding the mutex.
      if [ "''${1:-}" != --serialized ]; then
        exec flock --close "''${XDG_RUNTIME_DIR:?}/gnesha-lock.lock" "$0" --serialized
      fi
      if pgrep -u "$UID" -x gtklock >/dev/null || pgrep -u "$UID" -x swaylock >/dev/null; then
        exit 0
      fi
      # No credentials are stored or sent: this only closes any open vaults.
      dbus-send --session --print-reply --reply-timeout=1000 \
        --dest=org.keepassxc.KeePassXC.MainWindow /keepassxc \
        org.keepassxc.KeePassXC.MainWindow.lockAllDatabases >/dev/null 2>&1 || true
      gtklock --daemonize || exec swaylock --daemonize
    '';
  };
in
{
  home.packages = [ lock pkgs.gtklock ];
  xdg.configFile."gtklock/config.ini".text = ''
    [main]
    gtk-theme=${config.gtk.theme.name}
    style=${config.xdg.configHome}/gtklock/style.css
    time-format=%H:%M
    date-format=%a, %d %b
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
    bindswitch --locked lid:on exec ${lock}/bin/gnesha-lock
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
