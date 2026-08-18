# Hosts

Each real directory is one NixOS host and is automatically emitted as
`nixosConfigurations.<directory-name>` by `flake.nix`. Directories beginning
with `_` are templates or notes and are excluded.

Host directories own machine-specific modules and the generated
`hardware-configuration.nix`. Copy `_template/` to add a host, then generate
hardware configuration for the target machine. User and consumer preferences
remain in root `params.nix`; discovery overlays the directory name as the
per-host `systemSettings.hostName`.
