# Content-sized Wayland notifications using the shared desktop palette.
{
  config,
  pkgs,
  variables,
  ...
}:
let
  v = import ../theme/palette.nix { inherit config pkgs; };
  appearance = {
    background = v.bg;
    foreground = v.foreground;
    frame_color = v.accent;
    timeout = 5;
  };
in
{
  services.dunst = {
    enable = true;
    settings = {
      global = {
        origin = "top-right";
        width = "(0, ${toString variables.notificationMaxWidth})";
        height = "(0, 220)";
        offset = "(10, 10)";
        frame_width = 2;
        corner_radius = 0;
        padding = 12;
        horizontal_padding = 12;
        font = "monospace ${toString variables.terminalFontSize}";
      };
      urgency_low = appearance;
      urgency_normal = appearance;
      urgency_critical = appearance // {
        frame_color = v.critical;
        timeout = 0;
      };
    };
  };
}
