# Shared Base16-to-terminal color assignment for Kitty's declarative config
# and the runtime theme preview. Values are bare hex strings, in color0-15
# order.
{ palette }:

map
  (field: builtins.replaceStrings [ "#" ] [ "" ] palette.${field})
  [
    "base03"
    "base08"
    "base0B"
    "base0A"
    "base0D"
    "base0E"
    "base0C"
    "base05"
    "base04"
    "base08"
    "base0B"
    "base0A"
    "base0D"
    "base0E"
    "base0C"
    "base07"
  ]
