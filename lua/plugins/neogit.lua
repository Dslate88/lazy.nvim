return {
  "NeogitOrg/neogit",
  lazy = true,
  dependencies = {
    "nvim-lua/plenary.nvim", -- required
    "sindrets/diffview.nvim", -- optional - Diff integration

    "folke/snacks.nvim",
  },
  cmd = "Neogit",
  keys = {
    { "<leader>ng", "<cmd>Neogit<cr>", desc = "Show Neogit UI" },
  },
}
