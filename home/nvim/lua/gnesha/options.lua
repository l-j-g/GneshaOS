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
