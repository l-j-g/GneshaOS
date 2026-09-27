# Documentation

These notes cover installation, parameters, host discovery, and safe build
workflows. Build a discovered host with
`nixos-rebuild build --flake .#<host-directory-name>`; activate the system with
`nixos-rebuild switch`, and activate the user environment separately with
`nh home switch . -c <user>@<host-directory-name>`.

- [`development.md`](development.md) describes the non-activating validation
  ladder, target discovery, dependency updates, and repository-local Codex
  workflow.
- [`recovery.md`](recovery.md) separates system generations from application
  data recovery and records the pending restore-drill requirements.
- [`user-parameters.md`](user-parameters.md) documents supported system and
  Home Manager preferences.
- [`install.md`](install.md) is the machine installation and recovery runbook.
- [`airvpn-proxy.md`](airvpn-proxy.md) covers the independent native host
  WireGuard connection, Docker Gluetun proxy, optional host HTTP proxy, and the
  direct-routing behavior when host VPN is off.
