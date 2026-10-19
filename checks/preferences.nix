# Evaluation-only regressions: the same rules run in Settings and Home Manager.
let
  base = import ../home/variables.nix;
  validate =
    overrides:
    import ../home/preferences/validate.nix {
      variables = base;
      inherit overrides;
    };
  invalid = [
    { browserDefaultZoom = 0.1; }
    { browserDefaultZoom = 8; }
    { browserDefaultZoom = "1.0"; }
    { idleDimPercent = 101; }
    { idleDimPercent = -1; }
    { idleDimSec = base.idleLockSec; }
    { idleSuspendSec = base.idleOffSec; }
    { idleLockSec = 800; }
    { hermesLocalPort = 0; }
    { hermesRemotePort = 65536; }
    { hermesSshHost = "host;command"; }
    { screenshotDir = "relative/path"; }
    { displayScale = "0"; }
    { displayScale = "invalid"; }
    { terminalFontSize = 0; }
    { terminalFontFamily = "monospace"; }
    {
      terminalFontFamily = "Terminus";
      terminalFontSize = 13;
    }
    { dictation.language = false; }
    { unknownPreference = true; }
  ];
  bindings = import ../home/desktop/sway/bindings.nix;
  args = builtins.mapAttrs (name: _: if name == "mod" then "Mod4" else name) (
    builtins.functionArgs bindings
  );
  shortcuts = bindings args;
in
assert validate { };
assert validate {
  browserDefaultZoom = 1;
  displayScale = "1.5";
  idleSuspendSec = null;
};
assert validate { dictation.language = "ja"; };
assert builtins.all (overrides: !validate overrides) invalid;
assert shortcuts."Mod4+Return".command == "exec term";
assert shortcuts."Mod1+j".command == "splith";
assert shortcuts."Mod1+k".command == "splitv";
assert
  shortcuts."--release Escape".command == "[app_id=\"floating_shell\" con_id=__focused__] kill";
true
