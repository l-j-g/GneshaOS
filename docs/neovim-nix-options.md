# Nix option documentation in Neovim

Use `K` on an option for nixd's hover documentation. Press `K` again to enter
that window and scroll it. Both hover and completion documentation include a
**Default** section supplied by the local nixd option-description helper.

Scalar defaults are evaluated in the selected flake configuration. For example,
`programs.direnv.enableFishIntegration` shows `true`, followed by its documented
reference to `home.shell.enableFishIntegration`. This is the option default,
not necessarily its configured value. Complex defaults use `defaultText` when
provided; otherwise they get a depth-limited preview. Failed default evaluation
is marked unavailable. The helper changes only the descriptions supplied to
nixd and leaves module configuration and completion snippets intact.

After rebuilding, restart Neovim (or its nixd client) to load the descriptions.
They use saved flake contents, so unsaved edits are excluded.

Completion suggestions show their kind and source in a bordered menu, beside a
bordered documentation panel. Use `Ctrl-d` and `Ctrl-f` to scroll that panel,
`Ctrl-e` to dismiss completion, and the existing Tab/Shift-Tab and Enter keys to
select and accept suggestions.

For default and evaluated values, use `<leader>nv` in a Nix buffer, or run:

```vim
:NixOption programs.git.enable
```

Select NixOS or Home Manager. With no command argument, enter a full dotted
option path at the prompt. The lookup uses the first configuration in the
selected flake output, matching the existing nixd configuration; this repository
has one of each. It supports ordinary dotted paths, rather than quoted attribute
names containing dots or options inside lists and submodules.

The result shows the option's type, declared default (or documented default
expression), and evaluated value. Values use JSON; functions and values that
throw an evaluation error are marked unavailable. Unsupported values nested in
collections can fail the lookup. An unknown option reports an error.

Evaluation runs asynchronously with a one-minute timeout and disables builds
from import-from-derivation. It reads the saved flake rooted at the current
buffer, so save changes first. The evaluated value can differ from the running
system or activated Home Manager generation. Nothing is built or activated.
