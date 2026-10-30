"""Capture one Wayland key combination; stdout is a Sway chord, Escape cancels."""
import sys

import gi

gi.require_version('Gtk', '4.0')
gi.require_version('Gdk', '4.0')
gi.require_version('Gtk4LayerShell', '1.0')
from gi.repository import Gdk, GLib, Gtk, Gtk4LayerShell as Layer


def main():
    result = []
    app = Gtk.Application(application_id='org.gnesha.CaptureKey')

    def activate(application):
        window = Gtk.ApplicationWindow(application=application, title='Set shortcut')
        Layer.init_for_window(window)
        Layer.set_namespace(window, 'gnesha-capture-key')
        Layer.set_layer(window, Layer.Layer.OVERLAY)
        # Exclusive focus keeps Sway from running the shortcut being recorded.
        Layer.set_keyboard_mode(window, Layer.KeyboardMode.EXCLUSIVE)
        label = Gtk.Label(label='Press the new key combination\nEscape cancels • Closes after 30 seconds')
        for side in ('top', 'bottom', 'start', 'end'):
            getattr(label, f'set_margin_{side}')(32)
        window.set_child(label)

        def pressed(controller, keyval, keycode, state):
            name = Gdk.keyval_name(keyval) or ''
            if name in ('Shift_L', 'Shift_R', 'Control_L', 'Control_R',
                        'Alt_L', 'Alt_R', 'Super_L', 'Super_R', 'Meta_L', 'Meta_R',
                        'Caps_Lock', 'Num_Lock', 'ISO_Level3_Shift', 'Mode_switch'):
                return True
            modifiers = [name for mask, name in (
                (Gdk.ModifierType.SUPER_MASK, 'Mod4'),
                (Gdk.ModifierType.CONTROL_MASK, 'Ctrl'),
                (Gdk.ModifierType.ALT_MASK, 'Mod1'),
                (Gdk.ModifierType.SHIFT_MASK, 'Shift'),
            ) if state & mask]
            if name == 'Escape' and not modifiers:
                application.quit()
                return True
            # Use the unshifted keysym, matching Sway's Shift+slash notation.
            translated = window.get_display().translate_key(
                keycode, Gdk.ModifierType(0), controller.get_current_event().get_layout())
            if translated[0]:
                name = Gdk.keyval_name(translated[1]) or name
            result.append('+'.join(modifiers + [name]))
            application.quit()
            return True

        controller = Gtk.EventControllerKey()
        controller.connect('key-pressed', pressed)
        window.add_controller(controller)
        GLib.timeout_add_seconds(30, lambda: application.quit())
        window.present()

    app.connect('activate', activate)
    app.run([])
    if not result:
        return 1
    print(result[0])
    return 0


if __name__ == '__main__':
    sys.exit(main())
