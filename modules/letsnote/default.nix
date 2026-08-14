{ config, pkgs, lib, ... }:

let
  cfg = config.letsnote;
in
{
  imports = [ ./power.nix ];

  options.letsnote = {
    ecFeatures = lib.mkEnableOption ''
      panasonic-laptop EC extras (charge limit/eco mode, hotkeys, backlight).
      Requires the acpi_osi kernel params to fool the BIOS into enabling them.
    '';
    fanControl = lib.mkEnableOption ''
      acpi_call kernel module + panafanpwr fan/power-mode daemon.
      The CF-FV1 is NOT yet supported by panafanpwr - enable at your own risk.
    '';
    jisKeys = lib.mkEnableOption ''
      keyd remap for the dead JIS keys (無変換/変換/かな) that have no US-layout
      binding: 無変換 -> Escape, 変換 (held) -> HJKL arrows layer,
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
              # 変換 (right of space) held -> arrow layer
              henkan = "layer(arrows)";
              # かな -> Right Alt (AltGr symbols)
              katakanahiragana = "layer(altgr)";
            };
            arrows = {
              h = "left";
              j = "down";
              k = "up";
              l = "right";
            };
          };
        };
      };
    })

    (lib.mkIf cfg.fanControl {
      boot.kernelModules = [ "acpi_call" ];
      boot.extraModulePackages = with config.boot.kernelPackages; [ acpi_call ];

      # EC namespace + quiet/eco byte (0x05) verified from this machine's
      # DSDT/SSDT2; matches CF-SV1. Firmware re-applies the fan profile on
      # wake via _WAK -> IETM.WAK -> REFM, so boot-time apply is sufficient.
      systemd.services.letsnote-fan-eco = {
        description = "Enable Let's Note EC quiet fan curve (SEFM eco)";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-modules-load.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "letsnote-fan-eco" ''
            printf '\\_SB.PC00.LPCB.EC0.SEFM 0x01\n' > /proc/acpi/call
          '';
        };
      };

      # Cold boots race the EC's own init and can overwrite an early write;
      # re-apply a couple of times after boot to be safe (no-op if already set).
      systemd.timers.letsnote-fan-eco-reapply = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = [ "45s" "180s" ];
          AccuracySec = "5s";
          Unit = "letsnote-fan-eco.service";
        };
      };
    })
  ];
}
