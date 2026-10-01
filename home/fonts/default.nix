{ lib, variables, ... }:

let
  family = variables.terminalFontFamily;
  profile = import ./profiles.nix { inherit family; };
in
{
  _module.args.fontProfile = profile;

  assertions = [
    {
      assertion = family != "" && !(builtins.elem family [ "monospace" "sans-serif" "serif" ]);
      message = "terminalFontFamily must name a real font family; applications use the monospace alias it configures.";
    }
  ];

  fonts.fontconfig = {
    enable = true;
    defaultFonts.monospace = [ family "Symbols Nerd Font Mono" ];
    configFile.gnesha-monospace-rendering = {
      enable = true;
      priority = 90;
      target = "90-gnesha-monospace-rendering.conf";
      text = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
          <!-- Rendering profile: ${profile.name}. -->
          <match target="font">
            <test name="family" compare="eq" qual="any">
              <string>${lib.escapeXML family}</string>
            </test>
            <edit name="antialias" mode="assign"><bool>${lib.boolToString profile.antialias}</bool></edit>
            <edit name="hinting" mode="assign"><bool>true</bool></edit>
            <edit name="autohint" mode="assign"><bool>false</bool></edit>
            <edit name="hintstyle" mode="assign"><const>${profile.hintstyle}</const></edit>
            <edit name="rgba" mode="assign"><const>${profile.rgba}</const></edit>
          </match>
        </fontconfig>
      '';
    };
  };
}
