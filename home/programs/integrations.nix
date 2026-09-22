# Shared application integrations and user-level application files.

{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Keep the Hermes UI on this machine while its agent backend remains on the
  # MacBook. The SSH alias is defined in ~/.ssh/config; the tunnel forwards
  # the MacBook's loopback-only Hermes dashboard to a local port.
  xdg.desktopEntries.hermes-mac = {
    name = "Hermes (MacBook)";
    comment = "Open the Hermes Agent running on the MacBook";
    exec = "${config.programs.firefox.finalPackage}/bin/firefox --new-window http://127.0.0.1:19119";
    terminal = false;
    categories = [ "Network" "Office" ];
  };

  # Optional local opencode config. Only installed when the file exists next
  # to the repo (it is machine-specific and intentionally not tracked), so a
  # fresh clone evaluates without it. Copy your own into place if you use it.
  # LF's previewer and wrapper live outside the Nix module so the preview
  # protocol stays readable and independently testable.
  xdg.configFile = (lib.optionalAttrs (builtins.pathExists ../../opencode.json) {
    "opencode/opencode.jsonc".source = ../../opencode.json;
  });
  home.file.".local/bin/lf-image" = {
    source = ./scripts/lf/lf-image;
    executable = true;
  };
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

  # Open files from nnn with nvim (text) / imv/mpv (media).
  home.sessionVariables = {
    NNN_OPENER = "nnn-opener";
    # preview-tui uses Kitty's split and graphics protocol when these are set.
    NNN_TERMINAL = "kitty";
    NNN_PREVIEWIMGPROG = "icat";
    KITTY_LISTEN_ON = "unix:/tmp/kitty";
  };
}
