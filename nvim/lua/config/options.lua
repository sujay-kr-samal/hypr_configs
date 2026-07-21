-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
-- Force global transparency everywhere (Bypasses Matugen/Colorscheme resets)
local function apply_transparency()
  local groups = {
    "Normal", "NormalFloat", "SignColumn", "NormalNC", "LineNr",
    "LazyNormal", "SnacksDashboardNormal", "SnacksDashboardHeader",
    "SnacksDashboardFooter", "SnacksDashboardDesc", "SnacksDashboardKey"
  }
  for _, group in ipairs(groups) do
    vim.api.nvim_set_hl(0, group, { bg = "none", ctermbg = "none" })
  end
end

-- Run transparency on startup AND every single time any colorscheme changes
apply_transparency()
vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
  pattern = "*",
  callback = apply_transparency,
})
