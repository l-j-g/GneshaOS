{ pkgs, ... }:

{
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd sway";
      user = "greeter";
    };
  };

  hardware.bluetooth.enable = true;

  # Enable the NixOS Steam integration (runtime libraries, udev rules, and
  # the supported launcher setup) for the gaming packages managed in Home
  # Manager.
  programs.steam.enable = true;

  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  services.libinput.enable = true;

  # Make login shell (fish) available system-wide and link portal files
  # when Home Manager runs with useUserPackages.
  programs.fish.enable = true;
  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];

}
