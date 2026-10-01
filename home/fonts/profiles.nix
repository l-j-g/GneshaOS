# Rendering defaults shared by Fontconfig and terminals that render directly.
{ family }:
let
  bitmap = builtins.elem family [ "Terminus" "Cozette" "CozetteCrossedSeven" "Dina" ]
    || builtins.match "Bm[0-9A-Za-z]* .*" family != null;
in
{
  name = if bitmap then "bitmap" else "outline";
  antialias = !bitmap;
  hintstyle = if bitmap then "hintfull" else "hintslight";
  # Grayscale avoids assuming a physical subpixel layout after output scaling.
  rgba = "none";
  freetypeFlags = if bitmap then "monochrome" else "no-monochrome";
  # These steps are specific to Terminus, not every bitmap family's strikes.
  terminusZoom = family == "Terminus";
}
