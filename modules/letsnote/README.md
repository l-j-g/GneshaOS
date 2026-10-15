# Let's Note module

This custom module provides EC features, CPU power controls, a model-specific
adaptive fan policy, and JIS-key handling for Panasonic Let's Note hardware.
`panafanpwr` is not used. Verify the model and kernel interfaces before enabling
hardware-specific options.

## CF-FV1 adaptive fan policy

`fanControl` supports CFFV1-1 with BIOS V1.00L25 only. Inspection of this
machine's ACPI tables found `SEFM`, plus `TFN1` and `TFN2` fan-level methods.
`SEFM(1)` maps to EC mode 5; it is not a tunable quietness percentage.
Linux exposes each channel as 50 steps of 2% control. These are requests,
not measured RPM. The controller requires both channels and the SEN6/CPU
sensors; every sensor discovered at startup must remain readable.

The hottest monitored SEN, CPU, or ACPI sensor selects the same request for
both fan channels, regardless of power source:

| Temperature | Request |
| --- | --- |
| Below 40C | 20% |
| 40–45C | 30% |
| 45–50C | 40% |
| 50–55C | 50% |
| 55–60C | 70% |
| 60–65C | 100% |

Increases happen on the next two-second sample. A decrease requires 20 seconds
below the current band's lower boundary minus 3C, then drops one band.
At 65C, on sensor errors, or when stopped, the controller restores `SEFM(0)`.
It does not automatically restart after a cutoff/error; inspect the journal
before restarting it. Startup at 60C or above leaves firmware control intact.
A systemd watchdog and independent `ExecStopPost` reset cover process failure.
Before suspend the service stops; after resume it starts again. The old boot
reapply timer is removed to avoid overriding fallback to firmware control.

The temporary trial was reported quieter; sustained charging, load, suspend,
and service-failure behavior of the installed service still need validation.
Changing BIOS versions requires another firmware inspection. Failure to reset
the EC requires a reboot; an ACPI return alone does not prove fan behavior.

After rebuilding, inspect `systemctl status letsnote-fan-eco` and
`journalctl -u letsnote-fan-eco -b`. To hand control back manually, use
`sudo systemctl stop letsnote-fan-eco`.

Host modules enable the options for a specific machine. Do not put disk UUIDs
or other generated hardware configuration here.
