# Validate a proposed literal edit with Nix itself; no nixpkgs import or build.
{
  original,
  candidate,
  key,
  valueJSON,
  fontSizesJSON,
}:
let
  before = import original;
  after = import candidate;
  value = builtins.fromJSON valueJSON;
  fontSizes = builtins.fromJSON fontSizesJSON;
  parts = builtins.filter builtins.isString (builtins.split "\\." key);
  replace =
    attrs: path:
    let
      name = builtins.head path;
      rest = builtins.tail path;
    in
    attrs // { ${name} = if rest == [ ] then value else replace attrs.${name} rest; };
  number = x: builtins.isInt x || builtins.isFloat x;
  text = x: builtins.isString x && x != "" && builtins.match "[^[:cntrl:]]+" x != null;
  positiveText =
    x:
    let
      parsed = builtins.tryEval (builtins.fromJSON x);
    in
    text x && parsed.success && number parsed.value && parsed.value > 0;
  valid =
    path: old: new:
    if builtins.isAttrs old then
      builtins.isAttrs new
      && builtins.attrNames old == builtins.attrNames new
      && builtins.all (
        name: valid (if path == "" then name else "${path}.${name}") old.${name} new.${name}
      ) (builtins.attrNames old)
    else if path == "idleSuspendSec" || old == null then
      new == null || (builtins.isInt new && new >= 0)
    else if builtins.isBool old then
      builtins.isBool new
    else if builtins.isInt old then
      builtins.isInt new && new >= 0
    else if builtins.isFloat old then
      number new && new > 0
    else if builtins.isString old then
      (if builtins.match "[0-9]+(\\.[0-9]+)?" old != null then positiveText new else text new)
    else
      false;
  fail = message: throw "Settings: ${message}";
in
if after != replace before parts then
  fail "The edit changed an unexpected preference."
else if !valid "" before after then
  fail "Use a value of the existing type; numbers must be in range and text must be nonempty and single-line."
else if !(after.idleDimSec < after.idleLockSec && after.idleLockSec < after.idleOffSec) then
  fail "Idle times must increase: dim < lock < screen off."
else if after.idleSuspendSec != null && after.idleSuspendSec <= after.idleOffSec then
  fail "Suspend must be later than screen off, or disabled."
else if after.terminalFontSize <= 0 || after.stackedViewFontSize <= 0 then
  fail "Font sizes must be greater than zero."
else if
  builtins.elem after.terminalFontFamily [
    "monospace"
    "sans-serif"
    "serif"
  ]
then
  fail "Select a real font family."
else if
  after.terminalFontFamily == "Terminus" && !builtins.elem after.terminalFontSize fontSizes
then
  fail "Select a supported Terminus bitmap size."
else
  true
