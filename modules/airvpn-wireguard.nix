{ config, lib, pkgs, params, ... }:

# System-wide AirVPN WireGuard tunnel, toggled from
# params.systemSettings.airVpn. The *.conf profile contains private keys and
# must stay out of the repo; point systemSettings.airVpn.configPath at a local
# file so wg-quick reads it at runtime instead of copying it into the store.
let
  avpn = params.systemSettings.airVpn or { };
in
{
  config = lib.mkIf (avpn.enable or false) {
    # wg-quick sets up the interface, routes (AllowedIPs 0.0.0.0/0), DNS, and
    # MTU from the profile. Requires the wireguard kernel module. resolvconf
    # propagates the AirVPN DNS servers while the tunnel is active.
    boot.kernelModules = [ "wireguard" ];
    environment.systemPackages = [ pkgs.wireguard-tools ];
    networking.resolvconf.enable = true;
    # NetworkManager must not manage the wg-quick interface: NM claims new
    # wireguard devices and flushes the address + routing table that
    # wg-quick configures, which makes the tunnel look up but carry no traffic.
    networking.networkmanager.unmanaged = [ "interface-name:airvpn-wg" ];

    systemd.services.airvpn-wg = {
      description = "AirVPN WireGuard tunnel";
      # Never start at boot; the Waybar toggle (or systemctl start) activates
      # the tunnel on demand.
      wantedBy = [ ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      script = ''
        # Runtime-work config so wg-quick derives its interface name from
        # airvpn-wg.conf, not the source profile filename.
        conf=/run/airvpn-wg.conf
        umask 077
        ${pkgs.coreutils}/bin/cp ${avpn.configPath} "$conf"
        ${pkgs.wireguard-tools}/bin/wg-quick up "$conf"
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStop = "${pkgs.wireguard-tools}/bin/wg-quick down /run/airvpn-wg.conf";
      };
    };

    # Let the desktop user start/stop the tunnel from Waybar without a
    # password prompt. Scope is limited to the airvpn-wg service.
    security.sudo.extraRules = [
      {
        groups = [ "wheel" ];
        commands = [
          {
            command = "${pkgs.systemd}/bin/systemctl start airvpn-wg";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.systemd}/bin/systemctl stop airvpn-wg";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.systemd}/bin/systemctl restart airvpn-wg";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
