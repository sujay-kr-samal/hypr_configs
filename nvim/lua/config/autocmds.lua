-- ~/.config/nvim/lua/config/autocmds.lua
-- Force transparency on every colorscheme load (belt-and-suspenders)

local function force_transparent()
  local groups = {
    -- Core windows
    "Normal", "NormalNC", "NormalFloat",
    "FloatBorder", "FloatTitle",
    -- Statusline / tabline
    "StatusLine", "StatusLineNC",
    "TabLine", "TabLineFill", "TabLineSel",
    "WinBar", "WinBarNC",
    -- Sidebar chrome
    "SignColumn", "FoldColumn",
    "EndOfBuffer",
    "VertSplit", "WinSeparator",
    -- Neotree
    "NeoTreeNormal", "NeoTreeNormalNC", "NeoTreeEndOfBuffer",
    "NeoTreeWinSeparator",
    -- Telescope
    "TelescopeNormal",        "TelescopeBorder",
    "TelescopePromptNormal",  "TelescopePromptBorder",
    "TelescopeResultsNormal", "TelescopeResultsBorder",
    "TelescopePreviewNormal", "TelescopePreviewBorder",
    -- Noice / notify
    "NoicePopup", "NoiceCmdlinePopup", "NoiceCmdlinePopupBorder",
    "NotifyBackground",
    "NoiceMini",
    -- Which-key
    "WhichKeyNormal", "WhichKeyBorder",
    -- Lazy / Mason popups
    "LazyNormal", "LazyBorder",
    "MasonNormal",
    -- Pum (autocomplete)
    "Pmenu", "PmenuSbar",
    -- Snacks dashboard
    "SnacksDashboardNormal",
    -- Snacks terminal (LazyVim built-in terminal)
    "SnacksTermNormal", "SnacksTermBorder",
    "SnacksNormal", "SnacksWinBar",
    "SnacksBackdrop",
    -- Snacks picker (fzf-style picker in LazyVim)
    "SnacksPickerNormal",  "SnacksPickerBorder",
    "SnacksPickerPreview", "SnacksPickerPreviewBorder",
    "SnacksPickerPrompt",  "SnacksPickerPromptBorder",
    "SnacksPickerList",    "SnacksPickerListBorder",
    -- Trouble
    "TroubleNormal", "TroubleNormalNC",
    -- Toggleterm (if used)
    "ToggleTerm1NormalFloat", "ToggleTerm2NormalFloat",
    "ToggleTerm3NormalFloat", "ToggleTerm4NormalFloat",
    -- Terminal buffer itself
    "Terminal",
  }

  for _, group in ipairs(groups) do
    -- Only clear bg; preserve fg/gui attributes set by the theme
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
    if ok then
      hl.bg      = nil
      hl.ctermbg = nil
      vim.api.nvim_set_hl(0, group, hl)
    end
  end
end

vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = force_transparent,
  desc = "Strip background colours for full terminal transparency",
})

-- Also run immediately after startup in case colorscheme was set before autocmds loaded
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    -- Short delay so all plugins have finished setting up their highlights
    vim.defer_fn(force_transparent, 50)
  end,
  desc = "Initial transparency pass on VimEnter",
})

-- Re-apply when a terminal buffer is opened (covers :terminal and snacks term)
vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.defer_fn(force_transparent, 10)
  end,
  desc = "Re-apply transparency when terminal buffer opens",
})