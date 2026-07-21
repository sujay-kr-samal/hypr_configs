-- ==========================================================================
-- 1. BASE OPTIONS (Auto-create undo directory)
-- ==========================================================================
local undodir = vim.fn.stdpath("state") .. "/undo"
if vim.fn.isdirectory(undodir) == 0 then
  vim.fn.mkdir(undodir, "p")
end
vim.opt.undodir = undodir
vim.opt.undofile = true

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = 'a'
vim.opt.clipboard = 'unnamedplus'
vim.opt.breakindent = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.termguicolors = true
vim.opt.signcolumn = 'yes'

-- Leaders must be set BEFORE lazy.nvim loads
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- ==========================================================================
-- 2. PLUGIN MANAGER & LAZYVIM CORE BOOTSTRAP
-- ==========================================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim and import LazyVim specs
require("lazy").setup({
  spec = {
    -- Import the main LazyVim framework
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    
    -- Load your desired theme & plugins into the specification
    { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
    { "lukas-reineke/indent-blankline.nvim", main = "ibl" },
    { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },
    { "numToStr/Comment.nvim", opts = {} },
    { "akinsho/bufferline.nvim", opts = { options = { separator_style = "slant" } } },
    
    -- LSP setups to integrate seamlessly with LazyVim's native LSP system
    {
      "neovim/nvim-lspconfig",
      opts = {
        servers = {
          pyright = {},
          nil_ls = {},
          lua_ls = {
            settings = {
              Lua = {
                runtime = { version = 'LuaJIT' },
                globals = { 'vim' },
                workspace = { checkThirdParty = false },
                telemetry = { enable = false },
              },
            }
          },
        },
      },
    },
  },
  defaults = {
    lazy = false, -- Load specs sequentially on startup for a single-file config
    version = false,
  },
  checker = { enabled = true },
})

-- ==========================================================================
-- 3. DYNAMIC THEME LOGIC (Matugen Integration)
-- ==========================================================================
_G.reload_matugen_colors = function()
  vim.schedule(function()
    local check_cat_installed = pcall(require, "catppuccin")
    if not check_cat_installed then return end

    local matugen_path = vim.fn.stdpath("config") .. "/matugen_colors.lua"
    local overrides = {}
    
    if vim.fn.filereadable(matugen_path) == 1 then
      local chunk = loadfile(matugen_path)
      if chunk then
        local colors = chunk()
        if type(colors) == "table" then
          overrides = { all = colors, mocha = colors }
        end
      end
    end

    for k, _ in pairs(package.loaded) do
      if k:match("^catppuccin") then
        package.loaded[k] = nil
      end
    end

    vim.cmd("hi clear")
    if vim.fn.exists("syntax_on") then
      vim.cmd("syntax reset")
    end
    vim.g.colors_name = nil

    local ok_cat, cat = pcall(require, "catppuccin")
    if ok_cat then
      cat.setup({
        flavour = "mocha",
        compile = { enabled = false }, 
        color_overrides = overrides,
        integrations = {
          cmp = true,
          gitsigns = true,
          nvimtree = true,
          treesitter = true,
          bufferline = true, 
          telescope = { enabled = true },
          indent_blankline = { enabled = true },
        },
      })
      vim.cmd("colorscheme catppuccin")
    end
    
    local ok_lualine, lualine = pcall(require, "lualine")
    if ok_lualine then
      lualine.setup { options = { theme = 'catppuccin-nvim' } }
    end
    
    vim.cmd("redraw!")
    vim.notify("Matugen colors reloaded via LazyVim!", vim.log.levels.INFO)
  end)
end

-- Initialize theme immediately
_G.reload_matugen_colors()

-- ==========================================================================
-- 4. CUSTOM CORE KEYMAPS
-- ==========================================================================
vim.keymap.set('n', '<C-n>', ':NvimTreeToggle<CR>', { desc = 'Toggle File Explorer' })
vim.keymap.set("n", "<Tab>", ":BufferLineCycleNext<CR>", { silent = true })
vim.keymap.set("n", "<S-Tab>", ":BufferLineCyclePrev<CR>", { silent = true })
vim.keymap.set("n", "<leader>x", ":bdelete<CR>", { silent = true, desc = "Close Buffer" })

-- ==========================================================================
-- 5. ASYNC DEBOUNCED FILE WATCHER FOR MATUGEN
-- ==========================================================================
local uv = vim.uv or vim.loop
local config_dir = vim.fn.stdpath("config")
local reload_timer = uv.new_timer()

local watcher = uv.new_fs_event()
if watcher then
  watcher:start(config_dir, {}, vim.schedule_wrap(function(err, filename, events)
    if not err and filename == "matugen_colors.lua" then
      reload_timer:stop()
      reload_timer:start(250, 0, vim.schedule_wrap(function()
        _G.reload_matugen_colors()
      end))
    end
  end))
end