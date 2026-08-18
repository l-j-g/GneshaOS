{ pkgs, params, ... }:

{
  # Docker engine + compose for the self-hosted media stack (Lidarr/Prowlarr/etc.)
  virtualisation.docker.enable = true;
  virtualisation.docker.autoPrune = {
    enable = true;
    dates = "weekly";
  };
  # Let the user run docker without sudo and manage the stack
  users.users.${params.userSettings.userName}.extraGroups = [
    "docker"
    "input"
  ];

  # Stop Docker *arr stack before /media unmounts (containers hold volumes).
  systemd.services.docker-compose-stop = {
    description = "Stop Docker *arr stack before /media unmount";
    wantedBy = [ "multi-user.target" ];
    # Stop the stack after Docker is available, but before its daemon and the
    # media filesystem shut down, so container teardown cannot race either.
    after = [ "docker.service" ];
    before = [ "media.mount" "shutdown.target" ];
    requires = [ "docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
      ExecStop = "${pkgs.docker}/bin/docker compose -f ${params.userSettings.arrComposePath} down";
      TimeoutStopSec = 60;
    };
  };

  # Private mesh VPN for reaching self-hosted services from any device anywhere
  services.tailscale.enable = true;
  services.gvfs.enable = true;
}
