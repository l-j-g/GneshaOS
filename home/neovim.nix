{
  config,
  pkgs,
  ...
}:

let
  initLua = builtins.readFile ./nvim/init.lua;
  plugins = with pkgs.vimPlugins; [
    nvim-lspconfig
    nvim-cmp
    cmp-nvim-lsp
    cmp-buffer
    cmp-path
    cmp-cmdline
    cmp_luasnip
    luasnip
    friendly-snippets
    nvim-tree-lua
    nvim-web-devicons
    telescope-nvim
    telescope-fzf-native-nvim
    plenary-nvim
    project-nvim
    vim-nix
    tokyonight-nvim
    nnn-vim
    (nvim-treesitter.withPlugins (p: with p; [
      tree-sitter-nix
      tree-sitter-bash
      tree-sitter-lua
      tree-sitter-python
      tree-sitter-toml
      tree-sitter-json
      tree-sitter-markdown
      tree-sitter-markdown-inline
    ]))
  ];
in
{
  xdg.configFile."nvim/lua/gnesha".source = ./nvim/lua/gnesha;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withPython3 = false;
    withRuby = false;
    inherit initLua plugins;

    extraPackages = with pkgs; [
      nixd
      nixfmt
      shellcheck
      bash-language-server
    ];
  };
}
