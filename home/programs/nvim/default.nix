{
  config,
  pkgs,
  lib,
  ...
}:

let
  initLua = builtins.readFile ./init.lua;
  palette = config.colorScheme.palette;
  paletteFields = [
    "base00"
    "base01"
    "base02"
    "base03"
    "base04"
    "base05"
    "base06"
    "base07"
    "base08"
    "base09"
    "base0A"
    "base0B"
    "base0C"
    "base0D"
    "base0E"
    "base0F"
  ];
  nvimDefaultTheme =
    "return {\n"
    + lib.concatMapStringsSep "\n" (field: "  ${field} = \"#${palette.${field}}\",") paletteFields
    + "\n}\n";
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
    pkgs.vimPlugins.which-key-nvim
    pkgs.vimPlugins.telescope-nvim
    pkgs.vimPlugins.telescope-fzf-native-nvim
    pkgs.vimPlugins.plenary-nvim
    pkgs.vimPlugins.project-nvim
    pkgs.vimPlugins.vim-nix
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
in
{
  xdg.configFile."nvim/lua/gnesha".source = ./lua/gnesha;
  home.file.".config/gnesha/nvim-default-theme.lua".text = nvimDefaultTheme;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withPython3 = false;
    withRuby = false;
    inherit initLua plugins;

    extraPackages = [
      pkgs.tree-sitter
      pkgs.shellcheck
      pkgs.bash-language-server
    ];
  };
}
