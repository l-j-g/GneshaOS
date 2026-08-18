# Host template

Copy this directory to `hosts/<host-name>/`, generate that machine's
`hardware-configuration.nix` with `nixos-generate-config`, and add the
host-specific modules needed by the machine. Directories beginning with `_`
are excluded from flake auto-discovery, so this template is not a build output.

Keep shared consumer/user defaults in the root `params.nix`; use the optional
`params.nix` in this directory for values that differ on this host (for
example its timezone, display, or hardware paths). The flake overlays only the
copied directory name as the host name for each discovered output.
