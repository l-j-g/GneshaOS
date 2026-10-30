# Enrich only nixd's view of options; leave the evaluated module configuration alone.
{ lib, options }:
let
  pretty =
    value:
    lib.generators.toPretty { multiline = false; } (
      lib.generators.withRecursion {
        depthLimit = 2;
        throwOnDepthLimit = false;
      } value
    );
  describe =
    option:
    let
      documented = option.defaultText or null;
      documentedText = if builtins.isAttrs documented then documented.text else documented;
      defaultExpression =
        if builtins.isString documentedText && lib.hasPrefix "[](#opt-" documentedText then
          "`${lib.removeSuffix ")" (lib.removePrefix "[](#opt-" documentedText)}`"
        else
          documentedText;
      # Prefer real scalar defaults, even when defaultText refers to another option.
      # Complex defaults with defaultText use that concise representation instead.
      evaluated = builtins.tryEval (
        if !(option ? default) then
          "No declared default"
        else if
          documented != null && (builtins.isAttrs option.default || builtins.isList option.default)
        then
          documentedText
        else
          pretty option.default
      );
      value = if evaluated.success then evaluated.value else "Default unavailable (evaluation failed)";
    in
    option
    // {
      description =
        (option.description or "")
        + "\n\n**Default:**\n```nix\n${value}\n```"
        + lib.optionalString (defaultExpression != null) "\n\n**Default expression:** ${defaultExpression}";
    };
  walk = builtins.mapAttrs (
    _: value:
    if lib.isOption value then
      describe value
    else if builtins.isAttrs value then
      walk value
    else
      value
  );
in
walk options
