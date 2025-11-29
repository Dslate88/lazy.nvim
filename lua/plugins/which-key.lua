return {
  "folke/which-key.nvim",
  dependencies = {
    "nvim-mini/mini.nvim",
  },
  opts = {
    spec = {
      {
        mode = { "n", "x" },
        -- TODO: find ways to integrate better icons for groupings..
        { "<leader>a", group = "ai", icon = "A" },
        { "<leader>h", group = "harpoon", icon = "H" },
      },
    },
  },
}
