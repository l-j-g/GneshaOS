# Rofi

- `launcher.nix` and `scripts/launcher`: `gnesha-rofi`, including the live theme
  and application PATH. The old Sway script path remains a compatibility link.
- `theme.nix`: declarative Rofi theme and the initial live theme.
- `settings.nix`: packages `gnesha-settings` and the **Gnesha Settings** launcher,
  and tells it which terminals are installed and which font sizes a bitmap face
  accepts.
- `scripts/settings.sh`: implements Rofi script mode, reads descriptions from
  `home/variables.nix`, and writes narrowly scoped literal edits.
- `keybindings.nix` generates the shortcut catalog and packages the menu;
  `scripts/keybindings.sh` edits keys through the shared Rofi launcher;
  `scripts/capture-key.py` records a key combination in a small Wayland window.
- `settings-validate.nix`: uses Nix built-ins to check the proposed values and
  ensure that only the selected preference changes. This Settings validator uses no Python.

Open **Gnesha Settings** through the normal application launcher, or run
`gnesha-settings`. Type to search names, descriptions, or variable names. Rows
show saved values, which can differ from the currently running configuration.

Rows are not written down anywhere: `home/variables.nix` stays a plain file of
literal assignments, and the editor reads the comment above each assignment as
that preference's description. The key is the row title and the saved value
decides whether the row is edited as On/Off, a number, or text. Types and
constraints live in `../../preferences/schema.nix`; numeric ranges also supply
prompt hints. Adding a preference requires its literal, comment, and schema entry.
A preference no module reads is left out of the menu, because editing it would
change nothing.

Fonts use a searchable list from `fc-list`; themes use the existing theme
catalog. Booleans offer On/Off. Numeric/text prompts show the saved value in
their message; type a new value and press Enter. **Back** returns to the preference
list. `disabled` turns off the nullable idle-suspend timer. Escape cancels without writing.

After editing, choose **Save only** to batch preferences or **Save and apply**
to open `home-rebuild` in a terminal. **Apply saved settings** on the main menu
also applies a batch after you have finished editing. Applying includes all pending Home Manager
changes. The terminal stays open so build or activation errors remain readable.
New font choices use `home/fonts` to configure the shared `monospace` alias;
applications may need restarting after activation.

The editor preserves comments and unrelated assignments, evaluates a temporary
Nix file, checks the shared preference types and constraints, including host overrides
and the idle timers' ordering, then replaces the source file atomically. It refuses
ambiguous/nonliteral assignments, concurrent source changes detected before or during validation, and writes while the
activation lock is held. It checks again immediately before replacement; an
external editor that ignores the lock can still race that final rename.
Host-overridden preferences direct you to the host file instead of silently editing an
ineffective root value. Cancelling or failing validation leaves the source alone.

When adding a preference, write it in `home/variables.nix` with a comment above
it and declare its type and constraints in `home/preferences/schema.nix`.
`home/preferences/default.nix` exposes these as `gnesha.preferences` Home Manager
options; `home/preferences/validate.nix` checks cross-field rules for Home Manager,
the flake, and this editor. Descriptions remain solely in `variables.nix`.

The callback tests exercise temporary preferences, including cancellation,
Nix interpolation escaping, invalid values, concurrent edits, and the activation
lock. Python is used only as the test runner. They are included in
`nix flake check`; run them directly without building or changing the desktop:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 checks/rofi-settings.py home/desktop/rofi/scripts/settings.sh
```

The shell uses Rofi's [script-mode protocol](https://davatorium.github.io/rofi/current/rofi-script.5/):
`ROFI_RETV` identifies selections and typed input, row `info` identifies actions,
and `ROFI_DATA` carries the pending edit between callbacks. There is no temporary
session directory to clean up when Escape closes the menu. Only a save creates a
candidate beside the preference file; it is removed if validation fails.

Open **Gnesha Keybindings** from the launcher or press **Super+Shift+/**
(Super+?) for searchable, editable shortcuts styled like Settings. Rows come
from the effective Home Manager Sway bindings (including binding modes), with
descriptions supplied by the structured records in
`../sway/keybindings.nix`. Metadata is used only when it matches the effective command;
overridden commands fall back to displaying the command. Search also matches commands.
Select an action, press the replacement combination, then choose **Save**.
Escape cancels recording or closes the menu. Recording times out after 30 seconds.
The recorder requests exclusive keyboard focus while recording.
The small recorder uses Python/GTK; the menu and safe
writes use shell and Nix.

Key changes are saved in `../sway/keybinding-edits.nix`. They rename keys in
Home Manager's merged `wayland.windowManager.sway.config.keybindings` and `modes`
options, retaining the commands and descriptions from their owning modules.
Commands are not copied into the edits file, so package updates keep working.
The editor preserves flags, checks for conflicting keys in the same mode, and
refuses to overwrite concurrent edits. Pressing an action's original combination
removes its saved change; deleting its entry from the file has the same effect.

Normal bindings no longer show `[default]`. Other modes remain labeled; behavior
flags appear as descriptions such as “on release” instead of part of the keys.
Bindings written directly in `sway-extra.conf` are outside these Nix options and
are not listed or checked for conflicts by this editor.
Super+Shift+K and Super+Shift+Up move a window up. The menu replaces the old
Super+? help overlay.
The catalog reflects the activated Home Manager generation, with pending key
changes overlaid immediately. Run **home-rebuild** to apply saved changes.
The menu never rebuilds, activates, or executes the selected shortcut.

The shortcut editor's checks run alongside the Settings checks in `nix flake check`.
Run them directly without building or changing the desktop:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 checks/rofi-keybindings.py home/desktop/rofi/scripts/keybindings.sh
```
