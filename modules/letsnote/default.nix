{ config, pkgs, lib, ... }:

let
  cfg = config.letsnote;
  fanController = "${pkgs.python3}/bin/python3 ${./fan.py}";
in
{
  imports = [ ./power.nix ];

  options.letsnote = {
    ecFeatures = lib.mkEnableOption ''
      panasonic-laptop EC extras (charge limit/eco mode, hotkeys, backlight).
      Requires the acpi_osi kernel params to fool the BIOS into enabling them.
    '';
    fanControl = lib.mkEnableOption ''
      Adaptive fan-level requests for the CF-FV1 with BIOS V1.00L25.
      Uses acpi_call and the two ACPI fan channels; RPM telemetry is unavailable.
    '';
    jisKeys = lib.mkEnableOption ''
      keyd remap for the dead JIS keys (無変換/変換/かな) that have no US-layout
      binding: 無変換 -> Escape, 変換 -> F13 (desktop dictation),
      かな -> Right Alt.
    '';
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.ecFeatures {
      boot.kernelModules = [ "panasonic-laptop" "psmouse" ];

      # Keep normal ACPI OSI reporting while debugging the internal touchpad.
      # Forced Windows OSI strings can change which ACPI input devices the
      # firmware exposes. Revisit EC feature enablement after input works.
      boot.kernelParams = [
        # CF-FV1 firmware reports PS/2 AUX as PNP-disabled; without this the
        # internal touchpad never creates an input device.
        "i8042.nopnp=1"
        # Force the controller's AUX probe and reset it during initialization.
        "i8042.nomux=1"
        "i8042.reset=1"
      ];

      # brightnessctl writes the backlight sysfs attribute directly. The
      # kernel exposes it as root:root 0644, so grant video-group users write
      # access for the desktop brightness keys and Waybar controls.
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="backlight", KERNEL=="intel_backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
        ACTION=="add", SUBSYSTEM=="backlight", KERNEL=="intel_backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
      '';
    })

    (lib.mkIf cfg.jisKeys {
      services.keyd.enable = true;
      services.keyd.keyboards = {
        default = {
          ids = [ "*" ];
          settings = {
            main = {
              # 無変換 (left of space) -> Escape
              muhenkan = "escape";
              # 変換 (right of space) -> dedicated desktop dictation key
              henkan = "f13";
              # かな -> Right Alt (AltGr symbols)
              katakanahiragana = "layer(altgr)";
            };
          };
        };
      };
    })

    (lib.mkIf cfg.fanControl {
      boot.kernelModules = [ "acpi_call" ];
      boot.extraModulePackages = [ config.boot.kernelPackages.acpi_call ];

      systemd.services.letsnote-fan-eco = {
        description = "Adaptive CF-FV1 fan control";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-modules-load.service" ];
        serviceConfig = {
          Type = "notify";
          ExecStart = fanController;
          # Also runs after a crash/watchdog kill, independently of Python cleanup.
          ExecStopPost = "${fanController} --restore";
          WatchdogSec = "15s";
          TimeoutStartSec = "30s";
          TimeoutStopSec = "10s";
          # A thermal cutoff or sensor error must leave the firmware in control.
          Restart = "no";
          UMask = "0077";
        };
      };

      # No boot reapply timer: only the running controller may select EC mode.
      # Restore firmware control before sleep, then reacquire it on resume.
      powerManagement.powerDownCommands = "${pkgs.systemd}/bin/systemctl stop letsnote-fan-eco.service";
      powerManagement.resumeCommands = "${pkgs.systemd}/bin/systemctl start --no-block letsnote-fan-eco.service";
    })
  ];
}
