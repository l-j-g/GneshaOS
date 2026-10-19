# Shared types and constraints. User-facing descriptions stay in variables.nix.
let
  number = value: builtins.isInt value || builtins.isFloat value;
  text =
    value: builtins.isString value && value != "" && builtins.match "[^[:cntrl:]]+" value != null;
  field = kind: check: { inherit kind check; };
  range =
    kind: minimum: maximum:
    (field kind (
      value:
      (if kind == "int" then builtins.isInt value else number value)
      && value >= minimum
      && value <= maximum
    ))
    // {
      hint = "Enter a number between ${toString minimum} and ${toString maximum}.";
    };
  string = field "str" text;
  boolean = field "bool" builtins.isBool;
  unsigned = field "int" (value: builtins.isInt value && value >= 0);
  positive = field "number" (value: number value && value > 0);
  absolute = field "str" (value: text value && builtins.substring 0 1 value == "/");
  port = range "int" 1 65535;
in
{
  dictation = {
    speechModel = string;
    language = string;
    cleanupModel = string;
  };
  themeName = string;
  browserDefaultZoom = range "number" 0.3 5.0;
  gitUserName = string;
  gitUserEmail = string;
  publicKeyFile = absolute;
  terminal = string;
  displayScale = field "str" (
    value:
    builtins.isString value
    && builtins.match "(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]+)?" value != null
    && builtins.fromJSON value > 0
  );
  gapsInner = unsigned;
  gapsOuter = unsigned;
  autotilingEnabled = boolean;
  terminalFontFamily = field "str" (
    value:
    text value
    && !(builtins.elem value [
      "monospace"
      "sans-serif"
      "serif"
    ])
  );
  stackedViewFontSize = positive;
  terminalFontSize = positive;
  notificationMaxWidth = unsigned;
  screenshotDir = absolute;
  screenshotUploadUrl = string;
  idleDimSec = unsigned;
  idleLockSec = unsigned;
  idleOffSec = unsigned;
  idleSuspendSec = field "nullableInt" (value: value == null || unsigned.check value);
  lidCloseSuspendOnBattery = boolean;
  idleDimPercent = range "int" 0 100;
  autoBrightness = boolean;
  hermesMacTunnelEnable = boolean;
  hermesSshHost = field "str" (
    value: text value && builtins.match "[A-Za-z0-9][A-Za-z0-9._-]*" value != null
  );
  hermesLocalPort = port;
  hermesRemotePort = port;
}
