{
  pkgs,
  lib,
  params,
  ...
}:

let
  arrDirectory = builtins.dirOf params.systemSettings.arrComposePath;
  airVpnProfile = pkgs.writeShellScriptBin "airvpn-profile" ''
    export GNESHA_ARR_DIRECTORY=${lib.escapeShellArg arrDirectory}
    export GNESHA_ARR_COMPOSE_FILE=${lib.escapeShellArg params.systemSettings.arrComposePath}
    exec ${pkgs.bash}/bin/bash ${./scripts/airvpn-profile} "$@"
  '';
in
{
  home.file.".local/bin/airvpn-profile" = {
    source = "${airVpnProfile}/bin/airvpn-profile";
    executable = true;
  };

  xdg.configFile."airvpn/proxy.compose.yaml" =
    lib.mkIf (params.systemSettings.dockerProxy.enable or false)
      {
        # JSON is valid YAML and keeps the published port in sync with the client.
        text = builtins.toJSON {
          services.gluetun = {
            environment.HTTPPROXY = "on";
            ports = [ "127.0.0.1:${toString params.systemSettings.dockerProxy.port}:8888/tcp" ];
          };
        };
      };
}
