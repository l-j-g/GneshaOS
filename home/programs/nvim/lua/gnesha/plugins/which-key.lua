local M = {}

function M.setup()
  local which_key = require("which-key")

  which_key.setup({})
  which_key.add({
    { "<leader>/", desc = "Clear search highlight" },
    { "<leader>f", group = "Find" },
    { "<leader>l", group = "LSP" },
    { "<leader>r", group = "Refactor" },
  })
end

return M
