{
  pkgs,
  ...
}:

{
  programs.gpg.enable = true;

  # GnuPG's agent owns the pinentry prompts, so its configuration lives with
  # the program instead of in home/services.
  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-qt;
  };
}
