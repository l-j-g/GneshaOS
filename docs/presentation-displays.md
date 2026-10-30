# Configure a projector or external display

Plug in the projector, then search for **Displays** in the application launcher.
Arrange screens by dragging them, select resolution and scaling, and click
**Apply**. Use an advertised mode supported by the projector.

Keep the Displays window open during the presentation; switch back to your
presentation application to use it. The launcher stops the `way-displays` user
service while this window is open so its automatic layout does not compete with
your manual changes. Closing the window restores the service if it was active
beforehand, and the saved automatic layout may immediately return. If automatic
display management was already stopped, the launcher leaves it stopped.

This configures an extended desktop for slides on the projector and presenter
notes on the laptop. It does not add screen mirroring. These manual adjustments
do not edit the Nix configuration. Persistent settings remain in
`home/desktop/sway/daemons.nix` and monitor values in `system-parameters.nix`.

Only one Displays session can run at a time. If the wrapper is terminated
normally or the GUI fails, it still attempts to restore the automatic manager.
If it is forcibly killed or restoration fails, recover with:

```sh
systemctl --user start way-displays.service
```

The launcher is also available from a terminal as `display-settings` after
rebuilding and activating the Home Manager configuration.
