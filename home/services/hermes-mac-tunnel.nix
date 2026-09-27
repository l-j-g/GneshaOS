{
  variables,
  pkgs,
  ...
}:

{
  # This is a user service. network-online.target here is only a user-manager
  # ordering hint; it does not establish that the system network is online.
  systemd.user.services = if variables.hermesMacTunnelEnable then {
    hermes-mac-tunnel = {
      Unit = {
        Description = "SSH tunnel to the MacBook Hermes backend";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        ExecStart = "${pkgs.openssh}/bin/ssh -N -T -o BatchMode=yes -o StrictHostKeyChecking=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -L ${toString variables.hermesLocalPort}:127.0.0.1:${toString variables.hermesRemotePort} ${variables.hermesSshHost}";
        Restart = "on-failure";
        # MacBook may be asleep/off-network. Avoid a tight restart loop and
        # journal flood while retaining automatic recovery when it returns.
        RestartSec = 60;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  } else { };
}
