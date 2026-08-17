local M = {}

function M.setup()
  local ok, nvim_tree = pcall(require, "nvim-tree")
  if not ok then
    return
  end

  vim.g.loaded_netrw = 1
  vim.g.loaded_netrwPlugin = 1

  nvim_tree.setup({
    view = {
      width = 32,
      side = "left",
      preserve_window_proportions = true,
    },
    renderer = {
      group_empty = true,
    },
    filters = {
      dotfiles = false,
    },
  })

  vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "File tree" })
end

return M
