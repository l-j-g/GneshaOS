# Validate a proposed literal edit with Nix itself; no nixpkgs import or build.
{
  original,
  candidate,
  key,
  valueJSON,
  fontSizesJSON,
  hostOverrides ? "",
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
  fail = message: throw "Settings: ${message}";
in
if after != replace before parts then
  fail "The edit changed an unexpected preference."
else if
  !(import ../../preferences/validate.nix {
    variables = after;
    overrides =
      if hostOverrides != "" && builtins.pathExists hostOverrides then import hostOverrides else { };
    inherit fontSizes;
  })
then
  fail "Use the declared preference types and ranges, supported font sizes, and increasing idle timers."
else
  true
