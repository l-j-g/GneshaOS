# Read one option without building or activating either configuration.
{
  flakePath,
  configurationSet,
  optionName,
}:
let
  flake = builtins.getFlake flakePath;
  configurations = builtins.getAttr configurationSet flake;
  configurationName = builtins.head (builtins.attrNames configurations);
  configuration = builtins.getAttr configurationName configurations;
  path = builtins.filter builtins.isString (builtins.split "\\." optionName);
  get = builtins.foldl' (value: name: builtins.getAttr name value);
  option = get configuration.options path;
  render =
    value:
    let
      result = builtins.tryEval (
        if builtins.isFunction value then throw "Function value" else builtins.toJSON value
      );
    in
    if result.success then
      result.value
    else
      "Unavailable (evaluation failed or value cannot be represented as JSON)";
in
if !(builtins.tryEval (option._type == "option")).success then
  throw "Unknown option: ${optionName}"
else if option._type != "option" then
  throw "Unknown option: ${optionName}"
else
  {
    configuration = configurationName;
    type = option.type.description or "Unknown";
    default =
      if option ? defaultText then
        if builtins.isAttrs option.defaultText then option.defaultText.text else option.defaultText
      else if option ? default then
        render option.default
      else
        "No declared default";
    current = render (get configuration.config path);
  }
