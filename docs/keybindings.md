# Keyboard shortcuts

Open the searchable reference with **Super+Shift+/**. Rows show a coloured
`[Category]`, a bold key combination, and `:: explanation`. Selecting a row
closes the reference; it does not execute the command or change the binding.

Edit `home/desktop/sway/keybindings.nix` to change the main shortcuts:

```nix
"${m}+Return" = bind "Launch" "Open terminal" "exec ${term}";
```

The attribute name is the Sway key combination. `bind` constructs a record with
`category`, `description`, and `command` fields. `keybinding-options.nix` defines
that record's type. `sway.nix` imports the records, assigns them to
`gnesha.keybindings`, and passes each `binding.command` to Sway through
`lib.mapAttrs`. The menu reads the resulting Sway bindings and attaches the
matching category and description.

Binding modes live in `home/desktop/sway/sway.nix`; feature modules such as
`home/desktop/sway/dictation.nix` can also contribute Sway bindings. The menu
includes those effective bindings, using the mode name (or `Sway`) as their
category and the command as their explanation when no metadata is available.

After editing, run the usual Home Manager rebuild to apply the configuration.
There is no separate remapping file or menu save step.

**Super+s** starts a stack around the focused window; **Super+w** starts a
tabbed container around it. Other windows stay beside that container. New
windows opened while it is focused join its stack or tabs.
