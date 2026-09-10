# Session daemons — the Manjaro-style systemd user services plus idle/config
# managers. All are tied to the sway session target.

{
  pkgs,
  lib,
  params,
  variables,
  ...
}:

let
  sessionTarget = "sway-session.target";
  system = params.systemSettings;
in
{
  # --- Idle: dim -> DPMS off -> suspend only on battery; lock before sleep.
  # Timeouts and dim level come from home/variables.nix.
  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = variables.idleDimSec;
        command = "${pkgs.brightnessctl}/bin/brightnessctl -s && ${pkgs.brightnessctl}/bin/brightnessctl set ${toString variables.idleDimPercent}";
        resumeCommand = "${pkgs.brightnessctl}/bin/brightnessctl -r";
      }
      {
        timeout = variables.idleOffSec;
        command = "${pkgs.sway}/bin/swaymsg \"output * power off\"";
        resumeCommand = "${pkgs.sway}/bin/swaymsg \"output * power on\"";
      }
      {
        timeout = variables.idleSuspendSec;
        command = "${pkgs.acpi}/bin/acpi --ac-adapter | grep -q 'on-line' || systemctl suspend";
      }
    ];
    # attrset form (list form is deprecated in home-manager). The initial
    # login screen is provided by greetd/tuigreet; this service only handles
    # idle and sleep locking inside an already-running Sway session.
    events = {
      before-sleep = "${pkgs.swaylock}/bin/swaylock";
    };
    systemdTargets = [ sessionTarget ];
  };

  # Monitor configuration daemon (keeps per-monitor config between connects).
  services.way-displays = {
    enable = true;
    systemdTarget = sessionTarget;
    settings = {
      # Use explicit scales instead of DPI-based auto-scaling.
      AUTO_SCALE = false;

      # The BenQ's native scale makes UI text too small in practice.
      SCALE = [
        {
          NAME_DESC = "BenQ RD280UA";
          SCALE = 2.0;
        }
      ];
    };
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
      After = [ sessionTarget ];
      PartOf = [ sessionTarget ];
    };
    Service = {
      ExecStart = "${pkgs.poweralertd}/bin/poweralertd";
      Restart = "on-failure";
    };
    Install.WantedBy = [ sessionTarget ];
  };

  # --- Adaptive ambient brightness. Wluma learns manual adjustments and
  # interpolates the preferred brightness for each ambient-light level.
  services.wluma = lib.mkIf variables.autoBrightness {
    enable = true;
    systemd = {
      enable = true;
      target = sessionTarget;
    };
    settings = {
      als.iio = {
        path = "/sys/bus/iio/devices";
        thresholds = {
          "0" = "night";
          "20" = "dark";
          "80" = "dim";
          "250" = "normal";
          "500" = "bright";
          "800" = "outdoors";
        };
      };
      output.backlight = [
        {
          name = "eDP-1";
          path = "/sys/class/backlight/${system.backlightDevice}";
          # Learn from ambient light only; avoid screen-content-driven changes.
          capturer = "none";
        }
      ];
    };
  };
}
