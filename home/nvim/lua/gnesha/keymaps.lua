local map = vim.keymap.set
local opts = { noremap = true }

-- Keep the cursor centered during common navigation actions.
map("n", "<C-d>", "<C-d>zz", opts)
map("n", "<C-u>", "<C-u>zz", opts)
map("n", "n", "nzzzv", opts)
map("n", "N", "Nzzzv", opts)
map("n", "<leader>/", "<cmd>nohlsearch<CR>", opts)

-- Window navigation matching the Sway and tmux bindings.
map("n", "<A-h>", "<C-w>h", opts)
map("n", "<A-j>", "<C-w>j", opts)
map("n", "<A-k>", "<C-w>k", opts)
map("n", "<A-l>", "<C-w>l", opts)

-- Keep visual selections active while indenting.
map("v", ">", ">gv", opts)
map("v", "<", "<gv", opts)
