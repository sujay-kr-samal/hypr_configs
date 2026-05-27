-- ~/.config/nvim/lua/plugins/lualine.lua
-- Lualine with catppuccin theme + transparent background

return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      local icons = require("lazyvim.config").icons

      opts.options = opts.options or {}

      -- Build a fully transparent theme directly from the palette
      -- (avoids "catppuccin theme not found" warning on some load orders)
      local colors = require("catppuccin.palettes").get_palette("mocha")
      opts.options.theme = {
        normal   = { a = { fg = colors.base,    bg = colors.mauve,   gui = "bold" },
                     b = { fg = colors.mauve,   bg = "NONE" },
                     c = { fg = colors.text,    bg = "NONE" } },
        insert   = { a = { fg = colors.base,    bg = colors.green,   gui = "bold" },
                     b = { fg = colors.green,   bg = "NONE" },
                     c = { fg = colors.text,    bg = "NONE" } },
        visual   = { a = { fg = colors.base,    bg = colors.flamingo, gui = "bold" },
                     b = { fg = colors.flamingo, bg = "NONE" },
                     c = { fg = colors.text,    bg = "NONE" } },
        replace  = { a = { fg = colors.base,    bg = colors.red,     gui = "bold" },
                     b = { fg = colors.red,     bg = "NONE" },
                     c = { fg = colors.text,    bg = "NONE" } },
        command  = { a = { fg = colors.base,    bg = colors.peach,   gui = "bold" },
                     b = { fg = colors.peach,   bg = "NONE" },
                     c = { fg = colors.text,    bg = "NONE" } },
        inactive = { a = { fg = colors.overlay1, bg = "NONE" },
                     b = { fg = colors.overlay1, bg = "NONE" },
                     c = { fg = colors.overlay1, bg = "NONE" } },
      }

      -- Keep section separators — they look great with transparency
      opts.options.component_separators = { left = "", right = "" }
      opts.options.section_separators = { left = "", right = "" }
      opts.options.globalstatus = vim.o.laststatus == 3

      opts.options.always_show_tabline = false

      opts.sections = opts.sections or {}
      opts.sections.lualine_a = {
        {
          "mode",
          fmt = function(str) return " " .. str end,
          color = { fg = colors.base, bg = colors.mauve, gui = "bold" },
        },
      }
      opts.sections.lualine_b = {
        {
          "branch",
          icon = "",
          color = { fg = colors.mauve, bg = "NONE" },
        },
        {
          "diff",
          symbols = { added = icons.git.added, modified = icons.git.modified, removed = icons.git.removed },
          diff_color = {
            added    = { fg = colors.green,  bg = "NONE" },
            modified = { fg = colors.yellow, bg = "NONE" },
            removed  = { fg = colors.red,    bg = "NONE" },
          },
        },
      }
      opts.sections.lualine_c = {
        {
          "diagnostics",
          symbols = {
            error = icons.diagnostics.Error,
            warn  = icons.diagnostics.Warn,
            info  = icons.diagnostics.Info,
            hint  = icons.diagnostics.Hint,
          },
          diagnostics_color = {
            error = { fg = colors.red,    bg = "NONE" },
            warn  = { fg = colors.yellow, bg = "NONE" },
            info  = { fg = colors.sky,    bg = "NONE" },
            hint  = { fg = colors.teal,   bg = "NONE" },
          },
        },
        {
          "filename",
          path = 1, -- relative path
          symbols = { modified = "  ", readonly = "", unnamed = "" },
          color = { fg = colors.text, bg = "NONE" },
        },
      }
      opts.sections.lualine_x = {
        {
          function() return require("noice").api.status.command.get() end,
          cond = function()
            local ok, noice = pcall(require, "noice")
            return ok and noice.api.status.command.has()
          end,
          color = { fg = colors.peach, bg = "NONE" },
        },
        {
          function() return require("noice").api.status.mode.get() end,
          cond = function()
            local ok, noice = pcall(require, "noice")
            return ok and noice.api.status.mode.has()
          end,
          color = { fg = colors.mauve, bg = "NONE" },
        },
        {
          "filetype",
          icon_only = true,
          separator = "",
          padding = { left = 1, right = 0 },
          color = { bg = "NONE" },
        },
      }
      opts.sections.lualine_y = {
        {
          "progress",
          separator = " ",
          padding = { left = 1, right = 0 },
          color = { fg = colors.subtext1, bg = "NONE" },
        },
        {
          "location",
          padding = { left = 0, right = 1 },
          color = { fg = colors.subtext1, bg = "NONE" },
        },
      }
      opts.sections.lualine_z = {
        {
          function() return "  " .. os.date("%R") end,
          color = { fg = colors.base, bg = colors.lavender, gui = "bold" },
        },
      }

      opts.inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { { "filename", path = 1, color = { fg = colors.overlay1, bg = "NONE" } } },
        lualine_x = { { "location", color = { fg = colors.overlay1, bg = "NONE" } } },
        lualine_y = {},
        lualine_z = {},
      }

      return opts
    end,
  },
}