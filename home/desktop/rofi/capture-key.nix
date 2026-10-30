# Package the graphical key capture helper used by the shortcut editor.
{ pkgs }:
let
  capturePython = pkgs.python3.withPackages (p: [ p.pygobject3 ]);
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "gnesha-capture-key";
  version = "1";
  dontUnpack = true;
  nativeBuildInputs = [
    pkgs.wrapGAppsHook4
    pkgs.gobject-introspection
  ];
  buildInputs = [
    pkgs.gtk4
    pkgs.gtk4-layer-shell
  ];
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    makeWrapper ${capturePython}/bin/python3 "$out/bin/gnesha-capture-key" \
      --add-flags ${./scripts/capture-key.py} \
      --prefix LD_PRELOAD : ${pkgs.gtk4-layer-shell}/lib/libgtk4-layer-shell.so
    runHook postInstall
  '';
}
