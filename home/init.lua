-- Clean, portable Neovim foundation.
-- Plugin configuration can be added declaratively in later steps.

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true
opt.scrolloff = 8
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4
opt.expandtab = true
opt.smartindent = true
opt.autoindent = true
opt.wrap = true
opt.showmode = true
opt.showmatch = true
opt.hidden = true
opt.termguicolors = true
opt.wildmenu = true
opt.wildmode = { "list:longest" }
opt.clipboard = "unnamedplus"
opt.swapfile = true

local swap_dir = vim.fn.expand("~/.cache/nvim/swap")
vim.fn.mkdir(swap_dir, "p")
opt.directory = swap_dir .. "//"

-- Keep the cursor centered during common navigation actions.
vim.keymap.set("n", "<C-d>", "<C-d>zz", { noremap = true })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { noremap = true })
vim.keymap.set("n", "n", "nzzzv", { noremap = true })
vim.keymap.set("n", "N", "Nzzzv", { noremap = true })
vim.keymap.set("n", "<leader>/", "<cmd>nohlsearch<CR>", { noremap = true })

-- Window navigation matching the Vim configuration.
vim.keymap.set("n", "<A-h>", "<C-w>h", { noremap = true })
vim.keymap.set("n", "<A-j>", "<C-w>j", { noremap = true })
vim.keymap.set("n", "<A-k>", "<C-w>k", { noremap = true })
vim.keymap.set("n", "<A-l>", "<C-w>l", { noremap = true })

-- Keep visual selections active while indenting.
vim.keymap.set("v", ">", ">gv", { noremap = true })
vim.keymap.set("v", "<", "<gv", { noremap = true })

-- Plugins are supplied declaratively by Home Manager/Nix.
-- No network clone during Neovim startup.

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- File tree: NERDTree-style project browser.
local tree_ok, nvim_tree = pcall(require, "nvim-tree")
if tree_ok then
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
end

-- Fuzzy finding.
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
vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "File tree" })
vim.keymap.set("n", "<leader>f", builtin.find_files, { desc = "Find files" })
vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Buffers" })
vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Help tags" })
vim.keymap.set("n", "<leader>fp", "<cmd>Telescope projects<CR>", { desc = "Projects" })

-- nnn file picker (nnn-vim): browse with nnn, open selections in nvim.
vim.g["nnn#set_default_windowsize"] = 1
vim.keymap.set("n", "<leader>n", "<cmd>NnnPicker<CR>", { desc = "nnn file picker" })

-- Project roots: .git, Nix flakes, and common language project files.
local project_ok, project = pcall(require, "project_nvim")
if project_ok then
  project.setup({
    detection_methods = { "lsp", "pattern" },
    patterns = { ".git", "flake.nix", "pyproject.toml", "package.json", "Cargo.toml" },
    silent_chdir = true,
  })
end

-- Completion: LSP, snippets, filesystem paths, and current-buffer words.
local cmp = require("cmp")
local luasnip = require("luasnip")
require("luasnip.loaders.from_vscode").lazy_load()

cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  }),
  sources = {
    { name = "nvim_lsp" },
    { name = "luasnip" },
    { name = "path" },
    { name = "buffer" },
  },
})

-- Modern Neovim 0.11+ LSP API. Avoid deprecated require("lspconfig") setup.
local capabilities = require("cmp_nvim_lsp").default_capabilities()

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
  callback = function(ev)
    local map = function(lhs, rhs, desc)
      vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, silent = true, desc = desc })
    end
    map("gd", vim.lsp.buf.definition, "Go to definition")
    map("gr", vim.lsp.buf.references, "References")
    map("K", vim.lsp.buf.hover, "Hover documentation")
    map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
    map("<leader>ca", vim.lsp.buf.code_action, "Code action")
    map("<leader>lf", vim.lsp.buf.format, "Format buffer")
    map("[d", vim.diagnostic.goto_prev, "Previous diagnostic")
    map("]d", vim.diagnostic.goto_next, "Next diagnostic")
  end,
})

vim.diagnostic.config({
  severity_sort = true,
  virtual_text = true,
  underline = true,
  float = { border = "rounded" },
})

for _, server in ipairs({ "nixd", "bashls" }) do
  vim.lsp.config(server, {
    capabilities = capabilities,
  })
  vim.lsp.enable(server)
end

vim.cmd.colorscheme("tokyonight-night")
