vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.diagnostic.config({
  severity_sort = true,
  virtual_text = true,
  underline = true,
  float = { border = "rounded" },
})

vim.cmd.colorscheme("tokyonight-night")
