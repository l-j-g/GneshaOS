# Evaluated by upstream's module system, with its own pinned pkgs/lib.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Upstream mainConfig explicitly disables viAlias.
  build.viAlias = lib.mkForce true;
  vim = {
    disableArrows = false;
    treesitter.grammars = lib.mkForce pkgs.vimPlugins.nvim-treesitter.allGrammars;
    globals = {
      mapleader = " ";
      maplocalleader = " ";
    };

    # Apply personal preferences after every upstream vimrc section.
    # Upstream owns plugins, LSP, completion and theme; do not load gnesha.init.
    configRC.personal =
      lib.nvim.dag.entryAfter
        (builtins.filter (name: name != "personal") (builtins.attrNames config.vim.configRC))
        ''
          lua << EOF
          ${builtins.readFile ./lua/gnesha/options.lua}
          ${builtins.readFile ./lua/gnesha/keymaps.lua}

          local function set_nix_indent()
            vim.opt_local.expandtab = true
            vim.opt_local.shiftwidth = 4
            vim.opt_local.softtabstop = 4
            vim.opt_local.tabstop = 4
          end

          if vim.bo.filetype == "nix" then
            set_nix_indent()
          end
          vim.api.nvim_create_autocmd("FileType", {
            pattern = "nix",
            callback = set_nix_indent,
          })
          EOF
        '';
  };
}
