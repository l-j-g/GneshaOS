# Docker engine and independently enabled Compose stacks.
{ params, ... }:
{
  imports = [ ./arr ];
  # Keep the engine available independently of optional stacks.
  virtualisation.docker.enable = true;
  virtualisation.docker.autoPrune = {
    enable = true;
    dates = "weekly";
  };
  # Docker must be able to pull the containers that provide the local proxy
  # even when that proxy is stopped. This only bypasses the proxy for daemon
  # registry traffic; qBittorrent still shares Gluetun's VPN namespace.
  systemd.services.docker.serviceConfig.UnsetEnvironment = [
    "http_proxy"
    "https_proxy"
    "all_proxy"
    "HTTP_PROXY"
    "HTTPS_PROXY"
    "ALL_PROXY"
  ];
  # Let the user run docker without sudo and manage the stack
  users.users.${params.userSettings.userName}.extraGroups = [
    "docker"
  ];

}
