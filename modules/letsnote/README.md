# Let's Note module

This custom module provides EC features, CPU power controls, a model-specific
EC quiet-profile request, and JIS-key handling for Panasonic Let's Note
hardware. `fanControl` uses `acpi_call` for the CF-FV1 request; it does not
provide fan telemetry or arbitrary speed control. `panafanpwr` is not used.
Verify the target model and kernel interfaces before enabling hardware-specific
options.

Host modules enable the options for a specific machine. Do not put disk UUIDs
or other generated hardware configuration here.
