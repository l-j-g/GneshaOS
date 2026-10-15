local M = {}

function M.setup()
  local telescope = require("telescope")

  telescope.setup({
    defaults = {
      sorting_strategy = "ascending",
      layout_config = {
        prompt_position = "top",
      },
      file_ignore_patterns = {
        "%.git/",
        "node_modules/",
        "result/",
      },
    },
  })

  pcall(telescope.load_extension, "fzf")
  pcall(telescope.load_extension, "projects")

  local builtin = require("telescope.builtin")
  local map = vim.keymap.set

  map("n", "<leader>f", builtin.find_files, { desc = "Find files" })
  map("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
  map("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
  map("n", "<leader>fb", builtin.buffers, { desc = "Buffers" })
  map("n", "<leader>fh", builtin.help_tags, { desc = "Help tags" })
  map("n", "<leader>fp", "<cmd>Telescope projects<CR>", { desc = "Projects" })
end

return M
