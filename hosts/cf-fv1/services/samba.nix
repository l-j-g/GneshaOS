{ params, ... }:

{
  # macOS SMB share for the exFAT media volume.
  # Access is limited to the home LAN; authentication uses Samba's
  # separate password database for the user from the top-level params.
  services.samba = {
    enable = true;
    openFirewall = false;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = params.systemSettings.hostName;
        security = "user";
        "map to guest" = "never";
        "server min protocol" = "SMB2";
        # This share is local-only. Do not publish SMB ports on LAN interfaces.
        "hosts allow" = "127.0.0.1 ::1";
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
