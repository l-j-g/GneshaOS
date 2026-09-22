{ pkgs, variables, ... }:

let
  # Firefox stores webpage zoom as a global content preference rather than a
  # normal user.js preference. AutoConfig runs before the profile is ready;
  # wait for it before opening the profile's content-preferences database.
  contentZoomConfig = ''
    (function () {
      const observers = Components.classes[
        "@mozilla.org/observer-service;1"
      ].getService(Components.interfaces.nsIObserverService);
      const onProfileReady = {
        observe: function () {
          observers.removeObserver(this, "profile-after-change");
          try {
            const contentPrefs = Components.classes[
              "@mozilla.org/content-pref/service;1"
            ].getService(Components.interfaces.nsIContentPrefService2);
            contentPrefs.setGlobal(
              "browser.content.full-zoom", ${builtins.toJSON variables.browserDefaultZoom}, null,
              { handleError: error => Components.utils.reportError(error) }
            );
          } catch (error) {
            Components.utils.reportError(error);
          }
        }
      };
      observers.addObserver(onProfileReady, "profile-after-change");
    })();
  '';
  zoomOverrides = {
    # Permit this store-managed AutoConfig script to use the content-pref
    # service. This does not disable the browser's web-content sandbox.
    extraAutoConfig = ''pref("general.config.sandbox_enabled", false);'';
    extraPrefs = contentZoomConfig;
  };
in
{
  assertions = [{
    assertion = variables.browserDefaultZoom >= 0.3 && variables.browserDefaultZoom <= 5.0;
    message = "browserDefaultZoom must be between 0.3 and 5.0.";
  }];
  programs.firefox = {
    enable = true;
    configPath = ".config/mozilla/firefox";
    package = pkgs.firefox.override zoomOverrides;
  };

  programs.librewolf = {
    enable = true;
    configPath = ".config/librewolf/librewolf";
    package = pkgs.librewolf-bin.override zoomOverrides;
  };
}
