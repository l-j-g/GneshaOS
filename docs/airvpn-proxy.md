# Independent host and Docker VPNs

The host and Docker have separate controls:

- `systemSettings.airVpn` configures the native host WireGuard service.
  The profile is imported as a NetworkManager connection named `AirVPN`, so
  it can be selected from `nmtui` or the Waybar VPN toggle. It does not
  autoconnect. Set `systemSettings.airVpn.configPath` in
  `system-parameters.nix` to the chosen profile path. Keep the source profile
  outside the repository and Nix store, mode 600, and either owned by root or
  by the configured user inside that user's home directory. Parent directories
  must not be group- or world-writable. The importer checks the file and its
  parent directories. It writes the parsed
  connection, including its private key, to a root-only file under
  `/etc/NetworkManager/system-connections`, then loads it into NetworkManager.
  The file and connection are removed when the loader stops; boot-time cleanup
  removes a stale generated file before NetworkManager starts. Do not reuse
  Docker's WireGuard device key for simultaneous tunnels.
  The importer accepts standard keys for interface addresses, DNS, MTU, and
  peers. It rejects hooks and unsupported directives instead of silently
  dropping them. When the profile defines DNS, the generated connection uses
  negative DNS priority to avoid falling back to physical-interface resolvers.
- `systemSettings.dockerProxy` enables Gluetun's HTTP CONNECT proxy and its
  loopback port (default 8888). Container clients on `arr_default` use
  `http://gluetun:8888`. qBittorrent shares Gluetun's VPN network namespace.
- `systemSettings.systemProxy` controls optional host HTTP/HTTPS and desktop
  proxy settings. Leave it disabled when using native host WireGuard.
  Pointing it at Gluetun makes proxy-aware host applications depend on Docker.

Docker registry pulls and Nix daemon downloads explicitly discard HTTP proxy
variables. They use host routing, including the native VPN when it is active.
The `rebuild` helper also clears stale proxy variables inherited from a login
session, so it can recover the system while Gluetun is stopped.

This machine's configured path is `~/.config/vpn/host.conf`:

```sh
install -d -m 700 "$HOME/.config/vpn"
install -m 600 "$HOME/Downloads/nz.conf" "$HOME/.config/vpn/host.conf"
```

If you choose a different `configPath`, use that same destination in the
installation commands. After installing a profile or changing the configured
path, rebuild and activate the system configuration, then load the connection
with `sudo systemctl restart airvpn-networkmanager-profile`. The importer only
loads the connection; it does not activate the tunnel. Restarting the loader
disconnects an active AirVPN session. Use `nmtui` to select and activate
`AirVPN`, or use the Waybar toggle.

Do not put profile contents in the repository or Nix store. The current
`nz.conf` has the same WireGuard device identity as the Docker Gluetun profile.
It can be listed in NetworkManager, but do not connect both tunnels
simultaneously until a separate AirVPN device profile has been registered and
installed. Keep the host tunnel disconnected during route changes.

## Runtime data

`systemSettings.arrComposePath` selects the existing runtime directory through
its parent. On this machine that remains `/home/lg/src/arr`, containing `.env`
and `config/`. The managed definition is `/etc/arr/compose.json`. Do not change
the runtime path without first migrating and checking the actual data.

Use `arr up -d`, `arr ps`, and `arr-doctor` for the managed stack. Normal startup
uses pinned images and preserves application data. The legacy custom Compose
path used by `AIRVPN_COMPOSE_FILE` can include the optional proxy override at
`~/.config/airvpn/proxy.compose.yaml`, controlled by `dockerProxy`.

## Verification

```sh
arr-doctor
curl --noproxy '*' --fail --max-time 20 https://cache.nixos.org/nix-cache-info
curl --noproxy '' --proxy http://127.0.0.1:8888 --fail --max-time 20 https://cache.nixos.org/nix-cache-info
systemctl show nix-daemon docker -p UnsetEnvironment
```

After applying both NixOS and Home Manager configurations, log out and back in
so applications drop the old host proxy environment. In Firefox and LibreWolf,
use system proxy settings instead of an old manual `127.0.0.1:8888` setting.
For an existing Fish shell, clear the obsolete settings immediately with:

```fish
set -e http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
```

Before activation, a broken proxy can be bypassed for a build command with:

```sh
env -u http_proxy -u https_proxy -u all_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY nixos-rebuild build --flake /home/lg/.config/nix#cf-fv1
```

This changes only the client process; an already running Nix daemon keeps its
old environment until the corrected system configuration is activated.
