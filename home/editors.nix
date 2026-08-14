{ config, pkgs, lib, ... }:

let
  initLua = builtins.readFile ./init.lua;
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withPython3 = false;
    withRuby = false;
    initLua = initLua;

    plugins = [
      pkgs.vimPlugins.nvim-lspconfig
      pkgs.vimPlugins.nvim-cmp
      pkgs.vimPlugins.cmp-nvim-lsp
      pkgs.vimPlugins.cmp-buffer
      pkgs.vimPlugins.cmp-path
      pkgs.vimPlugins.cmp-cmdline
      pkgs.vimPlugins.cmp_luasnip
      pkgs.vimPlugins.luasnip
      pkgs.vimPlugins.friendly-snippets
      pkgs.vimPlugins.nvim-tree-lua
      pkgs.vimPlugins.nvim-web-devicons
      pkgs.vimPlugins.telescope-nvim
      pkgs.vimPlugins.telescope-fzf-native-nvim
      pkgs.vimPlugins.plenary-nvim
      pkgs.vimPlugins.project-nvim
      pkgs.vimPlugins.vim-nix
      pkgs.vimPlugins.tokyonight-nvim
      pkgs.vimPlugins.nnn-vim
      (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
        p.tree-sitter-nix
        p.tree-sitter-bash
        p.tree-sitter-lua
        p.tree-sitter-python
        p.tree-sitter-toml
        p.tree-sitter-json
        p.tree-sitter-markdown
        p.tree-sitter-markdown-inline
      ]))
    ];

    extraPackages = with pkgs; [
      nixd
      nixfmt
      shellcheck
      bash-language-server
    ];
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "lg";
        email = "lg@lgreve.com";
      };
      init.defaultBranch = "main";
      core.autocrlf = "input";
    };
  };

  programs.gh.enable = true;
}