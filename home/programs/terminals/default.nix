# Terminal programs and their configuration.
# Ghostty is the active terminal; Kitty remains enabled for nnn/theme-preview
# integrations, and Foot remains available as an optional module.

{
  imports = [
    ./ghostty.nix
    ./kitty.nix
  ];
}
