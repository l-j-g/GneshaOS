# CPU power management for the Let's Note CF-FV1.
# The fans are EC/ACPI-managed (read-only RPM; panafanpwr doesn't support CF-FV1).
# RAPL powercap constraint files are read-only on this kernel, so we use
# intel_pstate frequency capping instead — same thermal/noise effect.
#
# AC:   max_perf_pct = 70  (rough balance, ~70% of max frequency)
# Batt: max_perf_pct = 50  (cooler + longer battery)
{ config, pkgs, lib, ... }:

let
  cfg = config.letsnote;
in
{
  options.letsnote.cpuPower = lib.mkEnableOption ''
    CPU power management: intel_pstate powersave governor + frequency capping
    (70% max perf on AC, 50% on battery). Cooler and quieter than stock.
  '';

  options.letsnote.cpuPowerAc = lib.mkOption {
    type = lib.types.int;
    default = 70;
    description = "intel_pstate max_perf_pct when on AC power.";
  };

  options.letsnote.cpuPowerBat = lib.mkOption {
    type = lib.types.int;
    default = 50;
    description = "intel_pstate max_perf_pct when on battery.";
  };

  config = lib.mkIf cfg.cpuPower {
    # intel_pstate active mode: "powersave" = efficient HWP, best for a laptop.
    powerManagement.cpuFreqGovernor = "powersave";

    systemd.services.letsnote-cpu-power-cap = {
      description = "Apply Let's Note CPU frequency cap (AC/battery aware)";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "letsnote-cpu-power-cap" ''
          set -e
          PSTATE=/sys/devices/system/cpu/intel_pstate
          ac=$(${pkgs.coreutils}/bin/cat /sys/class/power_supply/AC/online 2>/dev/null || echo 1)
          if [ "$ac" = "1" ]; then
            cap=${toString cfg.cpuPowerAc}
          else
            cap=${toString cfg.cpuPowerBat}
          fi
          echo "$cap" > "$PSTATE/max_perf_pct"
        '';
      };
    };

    # Re-apply the cap whenever the power source changes (plug/unplug).
    services.udev.extraRules = ''
      ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="AC", RUN+="${pkgs.systemd}/bin/systemctl restart letsnote-cpu-power-cap.service"
    '';
  };
}
