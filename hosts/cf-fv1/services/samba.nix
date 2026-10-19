{ params, ... }:

{
  # macOS SMB share for the exFAT media volume.
  # Localhost, home LAN, and tailnet clients use Samba's separate password
  # database for the user from the top-level params.
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = params.systemSettings.hostName;
        security = "user";
        "map to guest" = "never";
        "server min protocol" = "SMB2";
        # Allow localhost, the home LAN, and the Tailscale tailnet; deny everything else.
        "hosts allow" = "127.0.0.1 ::1 192.168.1.0/24 100.64.0.0/10";
        "hosts deny" = "ALL";
      };
      media = {
        path = params.systemSettings.mediaMountPoint;
        browseable = "yes";
        "read only" = "no";
        "valid users" = params.userSettings.userName;
        "force user" = params.userSettings.userName;
        "create mask" = "0664";
        "directory mask" = "0775";
      };
    };
  };

}
