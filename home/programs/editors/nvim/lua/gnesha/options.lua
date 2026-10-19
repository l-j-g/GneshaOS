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
opt.autoread = true

-- Check external edits when returning to Neovim or entering a buffer.
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
    group = vim.api.nvim_create_augroup("GneshaAutoRead", { clear = true }),
    callback = function()
        vim.schedule(function()
            vim.cmd("checktime")
        end)
    end,
})

local swap_dir = vim.fn.expand("~/.cache/nvim/swap")
vim.fn.mkdir(swap_dir, "p")
opt.directory = swap_dir .. "//"
