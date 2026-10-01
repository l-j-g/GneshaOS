# Rofi

- `launcher.nix` and `scripts/launcher`: `gnesha-rofi`, including the live theme
  and application PATH. The old Sway script path remains a compatibility link.
- `theme.nix`: declarative Rofi theme and the initial live theme.
- `settings.nix`: packages `gnesha-settings` and the **Gnesha Settings** launcher.
- `scripts/settings.py`: preference descriptions, input types, menu flow,
  validation, and narrowly scoped writes to `home/variables.nix`.

Open **Gnesha Settings** through the normal application launcher, or run
`gnesha-settings`. Type to search names, descriptions, or variable names. Rows
show saved values, which can differ from the currently running configuration.

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
Nix file, checks value types/ranges and related idle times, then replaces the
source file atomically. It refuses ambiguous/nonliteral assignments, concurrent
source changes, and writes while the activation lock is held. Host-overridden
preferences direct you to the host file instead of silently editing an
ineffective root value. Cancelling or failing validation leaves the source alone.

When adding preferences, extend `FIELDS` and validation in `scripts/settings.py`.
The catalog test checks that every leaf in `home/variables.nix` is covered.
Run the isolated editor/menu tests without changing the live desktop:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 checks/rofi-settings.py home/desktop/rofi/scripts/settings.py
```
