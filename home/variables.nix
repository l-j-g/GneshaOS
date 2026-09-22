# Home Manager preferences.
#
# This is the user-facing customization file for the home environment. Edit
# these values when tuning the desktop, terminal, theme, or shell identity.
# Stable machine values belong in ../system-parameters.nix instead.

{
  # Base16 theme name. Use "matrix-green" or any scheme exposed by
  # nix-colors, such as "ayu-dark", "dracula", or "nord".
  themeName = "ayu-dark";

  # Default webpage zoom for Firefox and LibreWolf (1.5 = 150%). Browser UI
  # scaling and any saved per-site zoom choices remain independent.
  browserDefaultZoom = 1.5;

  # Name and email written into commits made with the configured Git client.
  gitUserName = "lg";
  gitUserEmail = "lg@lgreve.com";

  # Terminal command used by Sway, rofi, and Waybar. Change this only when the
  # matching terminal program is enabled under home/programs/terminals/.
  terminal = "kitty";

  # Sway output scale. "1" is 100%, "2" is 200% HiDPI. Fractional values
  # such as "1.5" are also accepted by Sway. The scale helper's "default"
  # command resets to this value.
  displayScale = "2";

  # Inner and outer gaps between Sway windows, in pixels.
  gapsInner = 5;
  gapsOuter = 5;

  # Font family used by Kitty. It is installed by modules/fonts.nix.
  terminalFontFamily = "Terminess Nerd Font Mono";

  # Font size, in points, for Sway stacked and tabbed window titles.
  stackedViewFontSize = 14;

  # Font size, in points, used by Kitty, Foot, Waybar, rofi, and mako.
  terminalFontSize = 16;

  # Directory where grimshot saves screenshots. A leading ~ is expanded to
  # the configured user's home directory by the Sway module.
  screenshotDir = "~/Pictures/Screenshots";

  # Anonymous image host used by the screenshot-upload binding. Change this
  # to another 0x0-compatible endpoint or leave it unchanged to keep uploads.
  screenshotUploadUrl = "https://x0.at/";

  # Lock on either power source; suspend remains battery-only.
  idleLockSec = 300;
  # Seconds before Sway dims the display, turns it off, and suspends on battery.
  idleDimSec = 240;
  idleOffSec = 600;
  idleSuspendSec = 900;

  # Brightness percentage used during the idle dim step.
  idleDimPercent = 10;

  # Enable wluma's adaptive ambient-brightness service. Set false if you want
  # brightness to remain entirely manual.
  autoBrightness = true;
}
