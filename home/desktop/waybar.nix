# waybar — top bar, matrix-themed, Manjaro-style module layout.

{
  config,
  pkgs,
  lib,
  params,
  variables,
  ...
}:

let
  v = import ../theme/palette.nix { inherit config pkgs; };
  sessionTarget = "sway-session.target";
  terminalCommand =
    if variables.terminal == "ghostty" then "${variables.terminal} -e" else variables.terminal;
in
{
  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      targets = [ sessionTarget ];
    };
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 45;
      spacing = 12;
      modules-left = [
        "sway/workspaces"
        "sway/mode"
      ];
      modules-center = [ "sway/window" ];
      modules-right = [
        "custom/vpn"
        "network"
        "bluetooth"
        "tray"
        "battery"
        "backlight"
        "pulseaudio"
        "memory"
        "cpu"
        "clock"
      ];

      # swayest-workstyle renames workspaces to app icons, so {name} shows them.
      "sway/workspaces" = {
        format = "{name}";
        tooltip = false;
      };

      "sway/window" = {
        max-length = 60;
        tooltip = false;
      };

      "cpu" = {
        interval = 5;
        format = "󰍛";
        states = {
          warning = 70;
          critical = 90;
        };
      };

      memory = {
        interval = 5;
        # Nerd Fonts v3 nf-md-memory; this is supplied by the symbol fallback.
        format = "󰘚";
        states = {
          warning = 70;
          critical = 90;
        };
      };

      backlight = {
        device = params.systemSettings.backlightDevice;
        format = "󰃟";
        on-scroll-up = "swayosd-client --brightness raise --device ${params.systemSettings.backlightDevice}";
        on-scroll-down = "swayosd-client --brightness lower --device ${params.systemSettings.backlightDevice}";
      };

      network = {
        interval = 5;
        format-wifi = "󰤨";
        format-ethernet = "󰈀";
        format-disconnected = "󰖪";
        tooltip-format-wifi = "{essid} ({signalStrength}%)\\n{ifname} {ipaddr}";
        tooltip-format-ethernet = "{ifname} {ipaddr}";
        tooltip-format-disconnected = "disconnected";
        on-click = "${terminalCommand} nmtui connect";
      };

      "custom/vpn" = {
        # vpn-toggle is installed to ~/.config/sway/scripts (on session PATH).
        exec = "vpn-toggle status";
        on-click = "vpn-toggle toggle";
        interval = 5;
        format = "{}";
        tooltip = true;
      };

      bluetooth = {
        format = "󰂯";
        format-disabled = "󰂲";
        tooltip-format = "{status}";
        on-click = "${terminalCommand} bluetuith";
        on-click-right = "rfkill toggle bluetooth";
      };

      pulseaudio = {
        format = "{icon}";
        format-muted = "󰝟";
        format-icons = {
          default = [
            "󰕿"
            "󰖀"
            "󰕾"
          ];
        };
        on-click = "pavucontrol";
        scroll-step = 2;
      };

      battery = {
        interval = 30;
        format = "{icon}";
        format-icons = [
          "󰂎"
          "󰁺"
          "󰁻"
          "󰁼"
          "󰁽"
          "󰁾"
          "󰁿"
          "󰂀"
          "󰂁"
          "󰂂"
          "󰁹"
        ];
        format-charging = "󰂄";
        states = {
          warning = 30;
          critical = 15;
        };
      };

      clock = {
        interval = 60;
        format = "{:%I:%M %p}";
        tooltip-format = "{:%a %d %b %Y}";
      };
    };

    style = ''
      * {
        font-family: monospace, "Symbols Nerd Font Mono";
        font-size: ${toString variables.terminalFontSize}pt;
        min-height: 0;
      }

      window#waybar {
        background: ${v.bg};
        color: ${v.foreground};
        border-bottom: 2px solid ${v.accent};
        border-radius: 0;
      }

      #workspaces button {
        color: ${v.subtle};
        padding: 0 8px;
        border-radius: 0;
        border-bottom: 2px solid transparent;
      }
      #workspaces button.focused {
        color: ${v.accent};
        background: ${v.bg};
        border-bottom: 2px solid ${v.accent};
      }
      #workspaces button:hover {
        background: ${v.surface};
        color: ${v.foreground};
      }

      #mode {
        background: ${v.accent};
        color: ${v.bg};
        padding: 0 8px;
      }

      #window {
        color: ${v.foreground};
      }

      #network, #bluetooth, #battery, #backlight, #pulseaudio, #memory, #cpu, #clock, #tray, #custom-vpn {
        padding: 0 6px;
      }

      #network.disconnected, #bluetooth.disabled { color: ${v.warning}; }

      #custom-vpn.connected { color: ${v.accent}; }
      #custom-vpn.disconnected { color: ${v.subtle}; }

      #battery.warning { color: ${v.warning}; }
      #battery.critical { color: ${v.critical}; }

      #pulseaudio.muted { color: ${v.critical}; }
      #cpu.warning, #memory.warning { color: ${v.warning}; }
      #cpu.critical, #memory.critical { color: ${v.critical}; }

      tooltip {
        background: ${v.surface};
        border: 1px solid ${v.accent};
        border-radius: 0;
      }
    '';
  };

  # Run Waybar as one managed user service. The live theme helper writes a
  # mutable stylesheet here and restarts this same service on Apply.
  home.activation.resetGneshaWaybarLiveStyle = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD install -Dm644 ${config.xdg.configFile."waybar/style.css".source} "$HOME/.config/gnesha/waybar-live.css"
  '';

  systemd.user.services.waybar.Service = {
    ExecStart = lib.mkForce "${pkgs.waybar}/bin/waybar -s ${config.home.homeDirectory}/.config/gnesha/waybar-live.css";
    ExecStartPre = "-${pkgs.procps}/bin/pkill -u %u -x waybar";
  };
}
