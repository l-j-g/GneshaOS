# Desktop HTTP proxy settings shared by applications using system defaults.
{ lib, params, ... }:

let
  proxy = params.systemSettings.systemProxy or { enable = false; };
in
{
  # Standard desktop proxy settings, also used by browsers in system mode.
  dconf.settings = {
    "org/gnome/system/proxy" = {
      mode = if proxy.enable then "manual" else "none";
    }
    // lib.optionalAttrs proxy.enable {
      use-same-proxy = false;
      ignore-hosts = map (host: if lib.hasPrefix "." host then "*${host}" else host) (
        lib.splitString "," proxy.noProxy
      );
    };
  }
  // lib.optionalAttrs proxy.enable {
    "org/gnome/system/proxy/http" = {
      host = proxy.host;
      port = proxy.port;
    };
    "org/gnome/system/proxy/https" = {
      host = proxy.host;
      port = proxy.port;
    };
  };

}
