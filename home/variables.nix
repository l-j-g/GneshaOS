# Home Manager preferences.
#
# This is the user-facing customization file for the home environment. Edit
# these values when tuning the desktop, terminal, theme, or shell identity.
# Stable machine values belong in ../system-parameters.nix instead.

{
  # Local dictation: hold 変換 (right of Space) to record; Shift cancels.
  # Larger speech/cleanup models trade latency and memory for accuracy.
  dictation = {
    # Name of a Whisper speech model that `voxtype setup` has downloaded.
    speechModel = "base.en";
    # Language code passed to the speech model, for example en or ja.
    language = "en";
    # Model used to clean up dictated text; larger models are more accurate.
    cleanupModel = "glm-5.3-flash";
  };

  # Base16 theme name. Use "matrix-green" or any scheme exposed by
  # nix-colors, such as "ayu-dark", "dracula", or "nord".
  themeName = "tokyo-night-storm";

  # Default webpage zoom for Firefox and LibreWolf (1.5 = 150%). Browser UI
  # scaling and any saved per-site zoom choices remain independent.
  browserDefaultZoom = 1.5;

  # Name and email written into commits made with the configured Git client.
  gitUserName = "lg";
  # Email address recorded in commits alongside the author name.
  gitUserEmail = "lg@lgreve.com";

  # Public PGP key file shown and optionally copied by the `pubkey` command.
  publicKeyFile = "/home/lg/public-key.asc";

  # Terminal command used by Sway, rofi, and Waybar. Change this only when the
  # matching terminal program is enabled under home/programs/terminals/.
  terminal = "ghostty";

  # Sway output scale. "1" is 100%, "2" is 200% HiDPI. Fractional values
  # such as "1.5" are also accepted by Sway. The scale helper's "default"
  # command resets to this value.
  displayScale = "1";

  # Gap between Sway windows, in pixels; zero removes the gap entirely.
  gapsInner = 5;
  # Gap around the workspace edge, in pixels; zero removes the gap entirely.
  gapsOuter = 5;

  # Automatically choose split orientation in Sway for newly mapped windows.
  # Each new window is oriented to its shape; a split chosen with Mod1+j /
  # Mod1+k is left alone until the next new window arrives.
  autotilingEnabled = true;

  # Preferred monospace family for the whole user desktop. Applications request
  # "monospace"; home/fonts maps that alias and selects a rendering profile.
  # Examples: "IBM Plex Mono", "BlexMono Nerd Font Mono", "Departure Mono",
  # "DepartureMono Nerd Font Mono", "Cozette", "Terminess Nerd Font Mono".
  terminalFontFamily = "IBM Plex Mono";

  # Font size, in points, for Sway stacked and tabbed window titles.
  stackedViewFontSize = 14;

  # Font size, in points, used by Kitty, Ghostty, Foot, Waybar, rofi, and mako.
  terminalFontSize = 16;

  # Directory where grimshot saves screenshots. Keep this on the MooGoo media
  # drive unless you intentionally want screenshots stored elsewhere.
  screenshotDir = "/media/Pictures/Screenshots";

  # Anonymous image host used by the screenshot-upload binding. Change this
  # to another 0x0-compatible endpoint or leave it unchanged to keep uploads.
  screenshotUploadUrl = "https://x0.at/";

  # Idle timers in seconds, which must increase in this order.
  # Dim the screen this long after the last input.
  idleDimSec = 900;
  # Lock the screen this long after the last input.
  idleLockSec = 1200;
  # Power the displays off this long after the last input.
  idleOffSec = 1800;
  # Suspend this long after the displays go off; null disables idle suspend.
  idleSuspendSec = null;
  # Lock and suspend on battery when the lid closes; AC closes only lock.
  lidCloseSuspendOnBattery = true;

  # Brightness percentage used during the idle dim step.
  idleDimPercent = 10;

  # Enable wluma's adaptive ambient-brightness service. Set false if you want
  # brightness to remain entirely manual.
  autoBrightness = true;

  # Start the Hermes tunnel and show its launcher together. SSH must have a
  # trusted known_hosts entry for this alias before the tunnel can connect.
  hermesMacTunnelEnable = true;
  # SSH host alias of the MacBook, as known to ssh on this machine.
  hermesSshHost = "mac";
  # Local port the tunnel listens on for the Hermes UI.
  hermesLocalPort = 19119;
  # Port the Hermes agent listens on, on the MacBook.
  hermesRemotePort = 9119;
}
