{ lib, params, ... }:

let
  proxy = params.systemSettings.systemProxy or { enable = false; };
  proxyUrl = "http://${proxy.host}:${toString proxy.port}";
in
{
  networking.hostName = params.systemSettings.hostName;
  networking.networkmanager.enable = true;

  # Optional host HTTP proxy, independent of the Docker Gluetun proxy.
  # Native AirVPN WireGuard routing does not require HTTP proxy variables.
  networking.proxy = lib.mkIf proxy.enable {
    httpProxy = proxyUrl;
    httpsProxy = proxyUrl;
    noProxy = proxy.noProxy;
  };

  # Builds must remain available while the optional application proxy is down.
  systemd.services.nix-daemon.serviceConfig.UnsetEnvironment = [
    "http_proxy" "https_proxy" "all_proxy"
    "HTTP_PROXY" "HTTPS_PROXY" "ALL_PROXY"
  ];

  # Local time = system timezone from the top-level params (should match the
  # wlsunset coordinates).
  time.timeZone = params.systemSettings.timeZone;

}
