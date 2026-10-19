# Pure validation shared by flake evaluation, Home Manager, and Settings.
{
  variables,
  overrides ? { },
  fontSizes ? import ../programs/terminals/font-sizes.nix,
}:
let
  schema = import ./schema.nix;
  merge =
    base: overlay:
    base
    // builtins.mapAttrs (
      name: value:
      if builtins.isAttrs value && builtins.isAttrs (base.${name} or null) then
        merge base.${name} value
      else
        value
    ) overlay;
  resolved = merge variables overrides;
  valid =
    spec: value:
    if spec ? kind then
      spec.check value
    else
      builtins.isAttrs value
      && builtins.attrNames spec == builtins.attrNames value
      && builtins.all (name: valid spec.${name} value.${name}) (builtins.attrNames spec);
in
valid schema resolved
&& resolved.idleDimSec < resolved.idleLockSec
&& resolved.idleLockSec < resolved.idleOffSec
&& (resolved.idleSuspendSec == null || resolved.idleSuspendSec > resolved.idleOffSec)
&& (resolved.terminalFontFamily != "Terminus" || builtins.elem resolved.terminalFontSize fontSizes)
