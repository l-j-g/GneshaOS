{ config, lib, pkgs, ... }:

let
  # greetd uses the login PAM substack, so configure login only once.
  passwordServices = [ "login" "sudo" "gtklock" "swaylock" ];
  faillock = "${pkgs.linux-pam}/lib/security/pam_faillock.so";
in
{
  # swaylock authenticates via PAM; without a registered service it falls
  # back to /etc/pam.d/other (pam_deny) and rejects every password.
  programs.gtklock.enable = true;

  # Five consecutive failures within 15 minutes: pause password attempts for
  # ten minutes. Successful authentication clears the tally. Root remains a
  # recovery route; counters in /run reset at reboot.
  environment.etc."security/faillock.conf".text = ''
    deny = 5
    fail_interval = 900
    unlock_time = 600
    silent
  '';
  security.pam.services = lib.genAttrs passwordServices (name: {
    allowNullPassword = lib.mkForce false;
    rules.auth = let order = config.security.pam.services.${name}.rules.auth.unix.order; in {
      faillock-preauth = {
        # Immediately precede the password module without renumbering others.
        order = order - 1;
        control = "requisite";
        modulePath = faillock;
        settings.preauth = true;
      };
      unix.control = lib.mkForce "[success=1 default=bad]";
      faillock-authfail = {
        order = order + 1;
        control = "[default=die]";
        modulePath = faillock;
        settings.authfail = true;
      };
      faillock-authsucc = {
        order = order + 2;
        control = "sufficient";
        modulePath = faillock;
        settings.authsucc = true;
      };
    };
  });

  # Keep the normal short sudo grace period on a portable machine.
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=5
  '';
}
