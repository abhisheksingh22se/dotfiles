return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          explorer = {
            -- Always show dotfiles and hidden files
            hidden = true,
            -- Move the explorer split to the right side
            layout = {
              layout = {
                position = "right",
              },
            },
          },
        },
      },
    },
  },
}
