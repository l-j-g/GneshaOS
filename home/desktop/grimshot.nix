# Screenshot wrapper with filenames safe for the media drive.
{ pkgs, ... }:

{
  # exFAT rejects ':' in filenames, while grimshot's default `date -Ins`
  # timestamp includes colons. Put a safe wrapper earlier in PATH so all
  # existing Sway screenshot bindings continue to work on the media drive.
  home.file.".local/bin/grimshot" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      set -eu
      if [ -z "''${GRIMSHOT_FILENAME_FORMAT:-}" ]; then
        export GRIMSHOT_FILENAME_FORMAT="$(${pkgs.coreutils}/bin/date +%Y-%m-%dT%H-%M-%S-%N)"
      fi
      exec ${pkgs.sway-contrib.grimshot}/bin/grimshot "$@"
    '';
  };
}
