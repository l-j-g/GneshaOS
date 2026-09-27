# Shared application integrations that do not belong to one program module.

{
  config,
  variables,
  ...
}:

{
  # Keep the Hermes UI on this machine while its agent backend remains on the
  # MacBook. Configuration itself lives in ~/.config/opencode/opencode.jsonc
  # and is read by OpenCode at runtime; credentials are never copied to Nix.
  xdg.desktopEntries = if variables.hermesMacTunnelEnable then {
    hermes-mac = {
      name = "Hermes (MacBook)";
      comment = "Open the Hermes Agent running on the MacBook";
      exec = "${config.programs.firefox.finalPackage}/bin/firefox --new-window http://127.0.0.1:${toString variables.hermesLocalPort}";
      terminal = false;
      categories = [ "Network" "Office" ];
    };
  } else { };
}
