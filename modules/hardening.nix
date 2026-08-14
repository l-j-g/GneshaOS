# Core hardening and hygiene: SSH, firewall, Nix GC, time sync, SSD trim.
# Requires `username` from specialArgs.

{
  config,
  pkgs,
  lib,
  username,
  ...
}:

{
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "video"
    ];

    shell = pkgs.fish;

    # TODO: set a login credential at first login (run `passwd`).
    # For fully declarative auth, set instead:
    #   hashedPassword = "...";  # from `mkpasswd -m sha-512`
    #   users.mutableUsers = false;

    # Authorized SSH keys for remote management. Add your public key here:
    # openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  services.chrony = {
    enable = true;
    makestep.enable = true;
  };

  services.fstrim.enable = true;

  # TPM2 userspace (Intel PTT firmware TPM): needed for systemd-cryptenroll
  # auto-unlock of the LUKS root volume and tpm2 tooling.
  security.tpm2.enable = true;

  # Laptop: drop to minimal state without breaking normal use.
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
}
