# AirVPN local proxy

Use the existing Gluetun container's built-in HTTP proxy. The Compose override
next to this document enables it and publishes port 8888 on loopback only.
NixOS sets the standard HTTP/HTTPS proxy environment and Home Manager sets the
desktop proxy to this address, controlled by `systemSettings.systemProxy`.
Compatible apps send requests through the existing Gluetun VPN connection;
qBittorrent keeps sharing Gluetun's network namespace. Both use the same VPN
server and are interrupted when that container restarts.

The Nix-managed stack in `hosts/cf-fv1/media.nix` includes this proxy when
`systemSettings.systemProxy.enable` is true. After activation, use `arr` to
manage it; no separate override is needed. See the [media stack notes](../hosts/cf-fv1/README.md).
The instructions below apply to the legacy Compose file before migration or
when explicitly selecting it with `AIRVPN_COMPOSE_FILE`.

Apply the override to the existing stack:

```sh
docker compose \
  -f /home/lg/src/arr/docker-compose.yml \
  -f /home/lg/.config/nix/docs/airvpn-proxy.compose.yaml \
  up -d --force-recreate gluetun qbittorrent
```

This restarts qBittorrent too, because it shares Gluetun's network namespace.
Keep both `-f` arguments when recreating these services; using only the base
file removes the proxy configuration. Home Manager installs the override at
`~/.config/airvpn/proxy.compose.yaml`; the updated `avpn` profile helper includes
it automatically when present.

Run the verification commands below **before activating** the proxy settings.
Once the proxy works, activate both configurations from this repository:

```sh
sudo nixos-rebuild switch --flake /home/lg/.config/nix#cf-fv1
nh home switch /home/lg/.config/nix -c lg@cf-fv1
```

Log out and back in so applications inherit the new environment. In Firefox
and LibreWolf, select **Use system proxy settings** in Network Settings if an
old manual setting overrides the system configuration. A proxy-aware terminal
request such as `curl --max-time 30 https://airvpn.org/` should then work without
an explicit `--proxy` argument.

In your application's manual proxy settings, use HTTP proxy host `127.0.0.1`
and port `8888`, including for HTTPS traffic. This is an HTTP CONNECT proxy,
not a SOCKS proxy. No proxy username or password is configured; it is available
only to clients on this computer. Do not enable fallback to a direct connection
if you want the application to fail when the proxy is unavailable.

Verify that the VPN is healthy and that a request can pass through the proxy:

```sh
docker inspect --format '{{.State.Health.Status}}' gluetun
curl --noproxy '' --proxy http://127.0.0.1:8888 --max-time 30 https://airvpn.org/
```

In a browser using the proxy, visit <https://ipleak.net/> and check that its
reported public IP belongs to the VPN. Browser features such as WebRTC and
application-specific DNS behavior need separate checking; an HTTP proxy does
not tunnel all computer traffic.

To disable system proxy use, set `systemSettings.systemProxy.enable = false`,
activate both configurations again, and log out and back in. If the proxy is
down, run rebuild commands with proxy variables removed using
`env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY`
before the command. Disabling client settings does not stop the torrent VPN.

If Gluetun is unhealthy, inspect `docker logs --tail 80 gluetun` locally before
changing VPN settings. Do not share private keys or credentials from logs or
profiles. The override enables the proxy; it cannot repair invalid VPN credentials
or an unreachable VPN endpoint.

Sources: [Gluetun HTTP proxy options](https://github.com/qdm12/gluetun-wiki/blob/main/setup/options/http-proxy.md)
and [WireGuard configuration-file support](https://github.com/qdm12/gluetun-wiki/blob/main/setup/options/wireguard.md).
