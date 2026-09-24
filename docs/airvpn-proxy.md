# Independent host and Docker VPNs

The host and Docker have separate controls:

- `systemSettings.airVpn` configures the native host WireGuard service.
  It starts only on demand from the Waybar toggle or `systemctl start airvpn-wg`.
  It does not depend on Docker. Use a separate AirVPN device profile outside
  the repository, for example `~/.config/airvpn/host.conf` (mode 600).
  Do not reuse Docker's WireGuard device key for simultaneous tunnels.
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

The host service is configured with a private copy of `Downloads/nz.conf` at
`~/.config/airvpn/host.conf`, and starts only on demand. This temporary profile
shares Docker's device key; replace it with a separate AirVPN device profile
for concurrent use. With the host tunnel stopped and host HTTP proxy disabled,
host internet access uses the direct network. Docker keeps its own VPN.

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
