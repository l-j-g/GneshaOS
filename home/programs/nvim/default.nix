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

    extraPackages = with pkgs; [
      nixd
      nixfmt
      shellcheck
      bash-language-server
    ];
  };
}
