# Explicit command manifest for scripts installed alongside the Sway config.
# Each wrapper provides only the runtime tools the command calls, so bindings
# do not depend on an interactive shell's PATH.
{
  config,
  pkgs,
  lib,
  params,
  variables,
  ...
}:

let
  user = params.userSettings;
  system = params.systemSettings;

  # The source files stay readable and retain their historic filenames under
  # ~/.config/sway/scripts. Wrappers establish a small, declared PATH first.
  mkCommand = name: source: interpreter: runtimeInputs:
    pkgs.writeShellScriptBin name ''
      export PATH=${lib.makeBinPath runtimeInputs}
      exec ${interpreter} ${source} "$@"
    '';
  sh = "${pkgs.dash}/bin/dash";
  bash = "${pkgs.bash}/bin/bash";
  python = "${pkgs.python3}/bin/python3";
  common = with pkgs; [ coreutils ];
  manifest = {
    "first-empty-workspace" = mkCommand "first-empty-workspace" ./scripts/first-empty-workspace python (with pkgs; [ python3 sway ]);
    "calcurse-daemon-enabled" = mkCommand "calcurse-daemon-enabled" ./scripts/calcurse-daemon-enabled sh (with pkgs; [ gawk ]);
    "ghostty-font-size-notify" = mkCommand "ghostty-font-size-notify" (pkgs.writeText "ghostty-font-size-notify" ghosttyFontSizeNotifyScript) sh (common ++ (with pkgs; [ sway jq libnotify gnused ]));
    # Rofi dispatches arbitrary selected applications, so keep the installed
    # Home Manager and system commands on PATH alongside its own runtime tools.
    "gnesha-rofi" = pkgs.writeShellScriptBin "gnesha-rofi" ''
      export PATH=${lib.makeBinPath (common ++ (with pkgs; [ rofi ]))}:${config.home.profileDirectory}/bin:/run/current-system/sw/bin:$PATH
      exec ${sh} ${./scripts/gnesha-rofi} "$@"
    '';
    "inhibit-idle" = mkCommand "inhibit-idle" ./scripts/inhibit-idle python (with pkgs; [ python3 sway ]);
    "once.sh" = mkCommand "once.sh" ./scripts/once.sh sh (common ++ (with pkgs; [ util-linux ]));
    "recorder.sh" = mkCommand "recorder.sh" ./scripts/recorder.sh sh (common ++ (with pkgs; [ libnotify slurp wf-recorder xdg-user-dirs ]));
    "scale.sh" = mkCommand "scale.sh" (pkgs.writeText "scale.sh" scaleScript) sh (common ++ (with pkgs; [ sway jq gawk way-displays libnotify ]));
    "sway-help" = mkCommand "sway-help" ./scripts/sway-help sh (common ++ (with pkgs; [ sway jq nwg-wrapper ]));
    "swaycwd" = mkCommand "swaycwd" ./scripts/swaycwd sh (common ++ (with pkgs; [ sway jq ]));
    "theme-picker" = mkCommand "theme-picker" (pkgs.writeText "theme-picker" themePickerScript) sh (common ++ (with pkgs; [ rofi libnotify util-linux gnugrep gnused kitty sway jq nix nh dash ]));
    "theme-preview" = mkCommand "theme-preview" (pkgs.writeText "theme-preview" themePreviewScript) sh (common ++ (with pkgs; [ gawk gnused kitty sway jq systemd ]));
    "vpn-toggle" = pkgs.writeShellScriptBin "vpn-toggle" ''
      export PATH=${lib.makeBinPath (common ++ (with pkgs; [ networkmanager gnugrep gawk sudo wireguard-tools ]))}
      export WG_BIN=${pkgs.wireguard-tools}/bin/wg
      exec ${bash} ${./scripts/vpn-toggle} "$@"
    '';
  };

  # scale.sh: "default" resets to the Sway-configured scale.
  scaleScript = lib.replaceStrings [ "__DEFAULT_SCALE__" ] [ variables.displayScale ] (builtins.readFile ./scripts/scale.sh);
  themePreviewScript = lib.replaceStrings [ "__TERMINAL_FONT_SIZE__" ] [ (toString variables.terminalFontSize) ] (builtins.readFile ./scripts/theme-preview);
  themePickerScript = lib.replaceStrings
    [ "__HOME_PROFILE__" "__ACTIVATION_LOCK__" ]
    [ "${user.userName}@${system.hostName}" "${config.home.path}/bin/gnesha-activation-lock" ]
    (builtins.readFile ./scripts/theme-picker);
  fontSizeValues = import ../../programs/terminals/font-sizes.nix;
  fontSizeCase = direction:
    lib.concatStringsSep "\n" (lib.imap0
      (index: size:
        let
          neighborIndex = if direction == "up" then index + 1 else index - 1;
          neighborExists = neighborIndex >= 0 && neighborIndex < builtins.length fontSizeValues;
          neighbor = if neighborExists then builtins.elemAt fontSizeValues neighborIndex else size;
          boundary = if neighborExists then "" else if direction == "up" then "; boundary=maximum" else "; boundary=minimum";
        in
        "            ${toString size}) next=${toString neighbor}${boundary} ;;")
      fontSizeValues);
  ghosttyFontSizeNotifyScript = lib.replaceStrings
    [ "__DEFAULT_FONT_SIZE__" "__FONT_SIZE_VALUES__" "__FONT_SIZE_UP_CASE__" "__FONT_SIZE_DOWN_CASE__" ]
    [ (toString variables.terminalFontSize)
      (lib.concatMapStringsSep "|" toString fontSizeValues)
      (fontSizeCase "up")
      (fontSizeCase "down")
    ]
    (builtins.readFile ./scripts/ghostty-font-size-notify);
  nwgWrapperStyle = lib.replaceStrings [ "__TERMINAL_FONT_SIZE__" ] [ (toString variables.terminalFontSize) ] (builtins.readFile ./nwg-wrapper/style.css);
in
{
  home.sessionPath = [ "$HOME/.config/sway/scripts" ];
  home.sessionVariables.GNESHA_FLAKE_PATH = system.flakePath;
  home.sessionVariables.GNESHA_TERMINAL_FONT_SIZE = toString variables.terminalFontSize;

  home.file = (lib.mapAttrs'
    (name: package: lib.nameValuePair ".config/sway/scripts/${name}" {
      source = "${package}/bin/${name}";
      executable = true;
    }) manifest) // {
    ".config/nwg-wrapper/help.sh".source = ./nwg-wrapper/help.sh;
    ".config/nwg-wrapper/style.css".text = nwgWrapperStyle;
  };
}
