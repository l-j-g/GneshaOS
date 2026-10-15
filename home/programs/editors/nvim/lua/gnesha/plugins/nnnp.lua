local M = {}

function M.setup()
  vim.g["nnn#set_default_windowsize"] = 1
  vim.keymap.set("n", "<leader>n", "<cmd>NnnPicker<CR>", { desc = "nnn file picker" })
end

return M
