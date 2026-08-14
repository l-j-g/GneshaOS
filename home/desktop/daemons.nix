# Session daemons — the Manjaro-style systemd user services plus idle/config
# managers. All are tied to the sway session target.

{
  config,
  pkgs,
  lib,
  ...
}:

let
  sessionTarget = "sway-session.target";
in
{
  # --- Idle: dim 240s, lock 300s, DPMS off 600s, suspend only on battery 900s.
  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 240;
        command = "${pkgs.brightnessctl}/bin/brightnessctl -s && ${pkgs.brightnessctl}/bin/brightnessctl set 10";
        resumeCommand = "${pkgs.brightnessctl}/bin/brightnessctl -r";
      }
      {
        timeout = 300;
        command = "${pkgs.swaylock}/bin/swaylock";
      }
      {
        timeout = 600;
        command = "${pkgs.sway}/bin/swaymsg \"output * power off\"";
        resumeCommand = "${pkgs.sway}/bin/swaymsg \"output * power on\"";
      }
      {
        timeout = 900;
        command = "${pkgs.acpi}/bin/acpi --ac-adapter | grep -q 'on-line' || systemctl suspend";
      }
    ];
    # attrset form (list form is deprecated in home-manager).
    events = {
      before-sleep = "${pkgs.swaylock}/bin/swaylock";
      lock = "${pkgs.swaylock}/bin/swaylock";
    };
    systemdTargets = [ sessionTarget ];
  };

  # Monitor configuration daemon (keeps per-monitor config between connects).
  services.way-displays = {
    enable = true;
    systemdTarget = sessionTarget;
  };

  # swayr — alt-tab style window switching.
  programs.swayr = {
    enable = true;
    systemd = {
      enable = true;
      target = sessionTarget;
    };
  };

  # Clipboard history (store + watch).
  services.cliphist = {
    enable = true;
    allowImages = true;
    systemdTargets = [ sessionTarget ];
  };

  # --- foot server (socket-activated) so footclient shares one instance.
  systemd.user.sockets.foot-server = {
    Unit = {
      Description = "Foot server socket";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Socket = {
      ListenStream = "%t/foot.sock";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.foot-server = {
    Unit = {
      Description = "Foot terminal server mode";
      Requires = [ "foot-server.socket" ];
      Documentation = "man:foot(1)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = "${pkgs.foot}/bin/foot --server=3";
      UnsetEnvironment = "LISTEN_PID LISTEN_FDS LISTEN_FDNAMES";
      NonBlocking = true;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # --- Workspace icons in waybar (renames workspaces to app icons).
  systemd.user.services.swayest-workstyle = {
    Unit = {
      Description = "Swayest workstyle workspace icons";
      PartOf = [ sessionTarget ];
      After = [ sessionTarget ];
    };
    Service = {
      ExecStart = "${pkgs.swayest-workstyle}/bin/swayest-workstyle -d -l error";
      NonBlocking = true;
      Restart = "on-failure";
    };
    Install.WantedBy = [ sessionTarget ];
  };

  # --- Focus flash animation.
  systemd.user.services.flashfocus = {
    Unit = {
      Description = "Flashfocus window focus animation";
      PartOf = [ sessionTarget ];
      After = [ sessionTarget ];
    };
    Service = {
      ExecStart = "${pkgs.flashfocus}/bin/flashfocus";
      Restart = "on-failure";
    };
    Install.WantedBy = [ sessionTarget ];
  };

  # --- Keep clipboard contents after the owning app closes.
  systemd.user.services.wl-clip-persist = {
    Unit = {
      Description = "wl-clip-persist clipboard persistence";
      PartOf = [ sessionTarget ];
      After = [ "sway-session-pre.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard regular --all-mime-type-regex '(?i)^(?!image/x-inkscape-svg).+'";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ sessionTarget ];
  };

  # --- Calendar reminders daemon.
  systemd.user.services.calcurse-daemon = {
    Unit = {
      Description = "Calcurse calendar daemon";
      PartOf = [ sessionTarget ];
      StartLimitBurst = 5;
      StartLimitIntervalSec = 30;
    };
    Service = {
      Type = "forking";
      ExecStartPre = "rm -f %h/.local/share/calcurse/.calcurse.pid %h/.local/share/calcurse/daemon.lock";
      ExecStart = "${pkgs.calcurse}/bin/calcurse --daemon";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ sessionTarget ];
  };

  # --- Keep playerctld alive so `playerctl` media keys stay responsive.
  systemd.user.services.playerctld = {
    Unit = {
      Description = "Playerctl media player daemon";
      PartOf = [ sessionTarget ];
    };
    Service = {
      ExecStart = "${pkgs.playerctl}/bin/playerctld daemon";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ sessionTarget ];
  };

  # --- PolicyKit authentication agent (auth prompts for mounts, etc).
  systemd.user.services.polkit-gnome = {
    Unit = {
      Description = "Polkit GNOME authentication agent";
      PartOf = [ sessionTarget ];
      After = [ "sway-session-pre.target" ];
    };
    Service = {
      ExecStart = "${pkgs.polkit_gnome}/bin/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ sessionTarget ];
  };

  # --- Auto split orientation.
  systemd.user.services.autotiling = {
    Unit = {
      Description = "Autotiling for Sway";
      PartOf = [ sessionTarget ];
      After = [ sessionTarget ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.autotiling}/bin/autotiling";
      Restart = "on-failure";
    };
    Install.WantedBy = [ sessionTarget ];
  };

  # --- Power status notifications (AC/battery transitions).
  systemd.user.services.poweralertd = {
    Unit = {
      Description = "Power status notifications";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.poweralertd}/bin/poweralertd";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # --- Ambient light sensor -> auto-brightness daemon.
  systemd.user.services.als-brightness = {
    Unit = {
      Description = "Ambient light sensor auto-brightness";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/home/desktop/scripts/als-brightness.sh";
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
