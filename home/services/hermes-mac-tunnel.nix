{
  pkgs,
  ...
}:

{
  # Keep the Hermes UI on this machine while its agent backend remains on the
  # MacBook. The SSH alias is defined in ~/.ssh/config; the tunnel forwards
  # the MacBook's loopback-only Hermes dashboard to a local port.
  systemd.user.services.hermes-mac-tunnel = {
    Unit = {
      Description = "SSH tunnel to the MacBook Hermes backend";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${pkgs.openssh}/bin/ssh -N -T -o BatchMode=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -L 19119:127.0.0.1:9119 mac";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
