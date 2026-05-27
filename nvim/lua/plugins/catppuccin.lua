-- ~/.config/nvim/lua/plugins/catppuccin.lua
-- Catppuccin theme with full transparency for LazyVim

return {
  -- 1. Add and configure catppuccin
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha", -- latte | frappe | macchiato | mocha
      background = {
        light = "latte",
        dark = "mocha",
      },
      transparent_background = true, -- Main transparency toggle

      show_end_of_buffer = false,
      term_colors = true,
      dim_inactive = {
        enabled = false,
        shade = "dark",
        percentage = 0.15,
      },
      no_italic = false,
      no_bold = false,
      no_underline = false,

      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
        loops = {},
        functions = {},
        keywords = {},
        strings = {},
        variables = {},
        numbers = {},
        booleans = {},
        properties = {},
        types = {},
        operators = {},
      },

      -- Catppuccin integrations — enable all common LazyVim plugins
      integrations = {
        cmp = true,
        gitsigns = true,
        nvimtree = true,
        neo_tree = true,
        treesitter = true,
        treesitter_context = true,
        notify = true,
        mini = {
          enabled = true,
          indentscope_color = "",
        },
        telescope = {
          enabled = true,
          style = "classic", -- "nvchad" can add unwanted backgrounds
        },
        which_key = true,
        indent_blankline = {
          enabled = true,
          scope_color = "lavender",
          colored_indent_levels = false,
        },
        dashboard = true,
        noice = true,
        lsp_trouble = true,
        mason = true,
        navic = {
          enabled = false,
          custom_bg = "NONE",
        },
        neotest = true,
        dap = true,
        dap_ui = true,
        flash = true,
        rainbow_delimiters = true,
        illuminate = {
          enabled = true,
          lsp = false,
        },
        native_lsp = {
          enabled = true,
          virtual_text = {
            errors = { "italic" },
            hints = { "italic" },
            warnings = { "italic" },
            information = { "italic" },
          },
          underlines = {
            errors = { "underline" },
            hints = { "underline" },
            warnings = { "underline" },
            information = { "underline" },
          },
          inlay_hints = {
            background = true,
          },
        },
        blink_cmp = true,
        snacks = true,
        fzf = true,
        render_markdown = true,
        gitgraph = true,
        lualine = true,
      },

      -- Custom highlight overrides to ensure full transparency
      custom_highlights = function(colors)
        return {
          -- ── Core windows ────────────────────────────────────────────────
          Normal            = { bg = "NONE" },
          NormalNC          = { bg = "NONE" },
          NormalFloat       = { bg = "NONE" },
          FloatBorder       = { bg = "NONE", fg = colors.lavender },
          FloatTitle        = { bg = "NONE", fg = colors.mauve },

          -- ── Statusline / tabline ────────────────────────────────────────
          StatusLine        = { bg = "NONE" },
          StatusLineNC      = { bg = "NONE" },
          TabLine           = { bg = "NONE" },
          TabLineFill       = { bg = "NONE" },
          TabLineSel        = { bg = "NONE", fg = colors.mauve, bold = true },
          WinBar            = { bg = "NONE" },
          WinBarNC          = { bg = "NONE" },

          -- ── Sidebars / splits ───────────────────────────────────────────
          SignColumn        = { bg = "NONE" },
          EndOfBuffer       = { bg = "NONE" },
          VertSplit         = { bg = "NONE", fg = colors.surface1 },
          WinSeparator      = { bg = "NONE", fg = colors.surface1 },

          -- ── Telescope ───────────────────────────────────────────────────
          TelescopeNormal         = { bg = "NONE" },
          TelescopeBorder         = { bg = "NONE", fg = colors.lavender },
          TelescopePromptNormal   = { bg = "NONE" },
          TelescopePromptBorder   = { bg = "NONE", fg = colors.mauve },
          TelescopeResultsNormal  = { bg = "NONE" },
          TelescopeResultsBorder  = { bg = "NONE", fg = colors.lavender },
          TelescopePreviewNormal  = { bg = "NONE" },
          TelescopePreviewBorder  = { bg = "NONE", fg = colors.lavender },

          -- ── Popup / completion menu ─────────────────────────────────────
          Pmenu             = { bg = "NONE" },
          PmenuSel          = { bg = colors.surface1 },
          PmenuSbar         = { bg = "NONE" },
          PmenuThumb        = { bg = colors.surface2 },

          -- ── Notify ──────────────────────────────────────────────────────
          NotifyBackground  = { bg = "NONE" },

          -- ── Noice ───────────────────────────────────────────────────────
          NoicePopup              = { bg = "NONE" },
          NoiceCmdlinePopup       = { bg = "NONE" },
          NoiceCmdlinePopupBorder = { bg = "NONE", fg = colors.mauve },
          NoiceMini               = { bg = "NONE" },

          -- ── Neo-tree ────────────────────────────────────────────────────
          NeoTreeNormal        = { bg = "NONE" },
          NeoTreeNormalNC      = { bg = "NONE" },
          NeoTreeEndOfBuffer   = { bg = "NONE" },
          NeoTreeWinSeparator  = { bg = "NONE", fg = colors.surface1 },

          -- ── Snacks dashboard ────────────────────────────────────────────
          SnacksDashboardNormal = { bg = "NONE" },
          SnacksDashboardHeader = { fg = colors.mauve, bold = true },

          -- ── Snacks terminal (LazyVim built-in terminal) ─────────────────
          SnacksTermNormal  = { bg = "NONE" },
          SnacksTermBorder  = { bg = "NONE", fg = colors.surface1 },
          SnacksNormal      = { bg = "NONE" },
          SnacksWinBar      = { bg = "NONE" },
          SnacksBackdrop    = { bg = "NONE" },

          -- ── Snacks picker (fzf-style, replaces Telescope in newer LazyVim)
          SnacksPickerNormal        = { bg = "NONE" },
          SnacksPickerBorder        = { bg = "NONE", fg = colors.lavender },
          SnacksPickerPreview       = { bg = "NONE" },
          SnacksPickerPreviewBorder = { bg = "NONE", fg = colors.lavender },
          SnacksPickerPrompt        = { bg = "NONE" },
          SnacksPickerPromptBorder  = { bg = "NONE", fg = colors.mauve },
          SnacksPickerList          = { bg = "NONE" },
          SnacksPickerListBorder    = { bg = "NONE", fg = colors.lavender },

          -- ── Which-key ───────────────────────────────────────────────────
          WhichKeyNormal    = { bg = "NONE" },
          WhichKeyBorder    = { bg = "NONE", fg = colors.lavender },

          -- ── Lazy.nvim UI ─────────────────────────────────────────────────
          LazyNormal        = { bg = "NONE" },
          LazyBorder        = { bg = "NONE", fg = colors.lavender },

          -- ── Mason ───────────────────────────────────────────────────────
          MasonNormal       = { bg = "NONE" },

          -- ── Toggleterm ──────────────────────────────────────────────────
          ToggleTerm1NormalFloat = { bg = "NONE" },
          ToggleTerm2NormalFloat = { bg = "NONE" },
          ToggleTerm3NormalFloat = { bg = "NONE" },
          ToggleTerm4NormalFloat = { bg = "NONE" },

          -- ── Git signs ───────────────────────────────────────────────────
          GitSignsAdd       = { fg = colors.green,  bg = "NONE" },
          GitSignsChange    = { fg = colors.yellow, bg = "NONE" },
          GitSignsDelete    = { fg = colors.red,    bg = "NONE" },

          -- ── Line numbers ────────────────────────────────────────────────
          LineNr            = { fg = colors.surface2, bg = "NONE" },
          CursorLineNr      = { fg = colors.lavender, bg = "NONE", bold = true },
          CursorLine        = { bg = colors.surface0 },

          -- ── Folds ───────────────────────────────────────────────────────
          Folded            = { bg = "NONE", fg = colors.overlay1, italic = true },
          FoldColumn        = { bg = "NONE" },

          -- ── Trouble ─────────────────────────────────────────────────────
          TroubleNormal     = { bg = "NONE" },
          TroubleNormalNC   = { bg = "NONE" },

          -- ── Terminal cursor ──────────────────────────────────────────────
          TermCursor        = { bg = colors.mauve, fg = colors.base },
        }
      end,
    },
  },

  -- 2. Override LazyVim's default colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}