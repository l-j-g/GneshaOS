{
  # swaylock authenticates via PAM; without a registered service it falls
  # back to /etc/pam.d/other (pam_deny) and rejects every password.
  security.pam.services.swaylock = { };

  # Cache sudo credentials for 30 minutes instead of the default 5.
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=30
  '';
}
