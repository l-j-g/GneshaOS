# Typed preference interface; editable values and descriptions stay in variables.nix.
{
  config,
  lib,
  hostVariables ? { },
  ...
}:
let
  schema = import ./schema.nix;
  types = {
    inherit (lib.types)
      str
      bool
      int
      number
      ;
    nullableInt = lib.types.nullOr lib.types.int;
  };
  declare =
    spec:
    if spec ? kind then
      lib.mkOption {
        type = lib.types.addCheck types.${spec.kind} spec.check;
      }
    else
      lib.mapAttrs (_: declare) spec;
  preferences = config.gnesha.preferences;
in
{
  options.gnesha.preferences = declare schema;
  config = {
    gnesha.preferences = lib.recursiveUpdate (import ../variables.nix) hostVariables;
    _module.args.variables = preferences;
    assertions = [
      {
        assertion = import ./validate.nix { variables = preferences; };
        message = "Desktop preferences must satisfy their types, ranges, font sizes, and idle timer ordering.";
      }
    ];
  };
}
