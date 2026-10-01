# Rofi

- `launcher.nix` and `scripts/launcher`: `gnesha-rofi`, including the live theme
  and application PATH. The old Sway script path remains a compatibility link.
- `theme.nix`: declarative Rofi theme and the initial live theme.
- `settings.nix`: packages `gnesha-settings` and the **Gnesha Settings** launcher,
  and tells it which terminals are installed and which font sizes a bitmap face
  accepts.
- `scripts/settings.py`: builds the menu from `home/variables.nix`, validates, and
  writes narrowly scoped changes back to it.

Open **Gnesha Settings** through the normal application launcher, or run
`gnesha-settings`. Type to search names, descriptions, or variable names. Rows
show saved values, which can differ from the currently running configuration.

Rows are not written down anywhere: `home/variables.nix` stays a plain file of
literal assignments, and the editor reads the comment above each assignment as
that preference's description. The key is the row title and the saved value
decides whether the row is edited as On/Off, a number, or text, so adding a
preference means writing the value and its comment and nothing else. A
preference no module reads is left out of the menu, because editing it would
change nothing.

Fonts use a searchable list from `fc-list`; themes use the existing theme
catalog. Booleans offer On/Off. Numeric/text prompts start with the saved value
and describe the expected units. `disabled` turns off the nullable idle-suspend
timer. Escape cancels without writing.

After editing, choose **Save only** to batch preferences or **Save and apply**
to open `home-rebuild` in a terminal. **Apply saved settings** on the main menu
also applies a batch after you have finished editing. Applying includes all pending Home Manager
changes. The terminal stays open so build or activation errors remain readable.
New font choices use `home/fonts` to configure the shared `monospace` alias;
applications may need restarting after activation.

The editor preserves comments and unrelated assignments, evaluates a temporary
Nix file, checks each value against the kind its own literal implies plus the
idle timers' ordering, then replaces the source file atomically. It refuses ambiguous/nonliteral assignments, concurrent
source changes, and writes while the activation lock is held. Host-overridden
preferences direct you to the host file instead of silently editing an
ineffective root value. Cancelling or failing validation leaves the source alone.

When adding a preference, write it in `home/variables.nix` with a comment above
it: the tests fail if a preference is undocumented or unread, and they run as
part of `nix flake check`. To iterate without changing the live desktop, run them
directly:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 checks/rofi-settings.py home/desktop/rofi/scripts/settings.py
```
