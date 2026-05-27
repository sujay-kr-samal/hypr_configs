-- ~/.config/nvim/lua/config/options.lua
-- Core options (merged with LazyVim defaults)

local opt = vim.opt

-- True-color terminal support (required for Catppuccin)
opt.termguicolors = true

-- Use the terminal's background (transparent)
opt.background = "dark"

-- General
opt.conceallevel = 2
opt.scrolloff    = 8
opt.sidescrolloff = 8
opt.number       = true
opt.relativenumber = true
opt.signcolumn   = "yes"
opt.cursorline   = true
opt.cursorlineopt = "number"
opt.wrap         = false
opt.splitbelow   = true
opt.splitright   = true

-- Indentation
opt.tabstop    = 2
opt.shiftwidth = 2
opt.expandtab  = true
opt.smartindent = true

-- Search
opt.ignorecase = true
opt.smartcase  = true
opt.hlsearch   = true
opt.incsearch  = true

-- Completion
opt.completeopt = { "menu", "menuone", "noselect" }
opt.pumblend = 0  -- 0 = no pseudo-transparency; use NONE bg instead
opt.pumheight = 12

-- Neovim UI
opt.winblend  = 0  -- keep 0 — let the theme handle transparency via NONE bgs
opt.cmdheight = 0
opt.showmode  = false
opt.ruler     = false
opt.laststatus = 3  -- global statusline

-- Disable swap/backup (personal preference)
opt.swapfile = false
opt.backup   = false
opt.undofile = true