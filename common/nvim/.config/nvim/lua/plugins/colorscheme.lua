return {
  {
    "folke/tokyonight.nvim",
    opts = {
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
      -- This function maps your exact WezTerm colors into Neovim
      on_colors = function(colors)
        colors.bg = "#050806"
        colors.bg_dark = "#050806"
        colors.bg_float = "#050806"
        colors.fg = "#A8E6B0"
        colors.fg_dark = "#D8FFE5"
        colors.fg_gutter = "#435048"

        -- ANSI Colors mapped from your WezTerm config
        colors.red = "#D05C65"
        colors.green = "#37D67A"
        colors.yellow = "#C9B458"
        colors.blue = "#609ED8"
        colors.magenta = "#A879C8"
        colors.cyan = "#56B6A9"

        -- Cursor and Selection
        colors.bg_visual = "#163D27" -- selection_bg
      end,
      -- Overriding specific UI elements for a cleaner look
      on_highlights = function(hl, c)
        hl.CursorLine = { bg = "#07100A" } -- Subtle highlight for the current line
        hl.TelescopeNormal = { bg = c.bg_dark, fg = c.fg }
        hl.TelescopeBorder = { bg = c.bg_dark, fg = c.bg_dark }
      end,
    },
  },
  -- Ensure LazyVim defaults to our customized tokyonight
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight",
    },
  },
}
