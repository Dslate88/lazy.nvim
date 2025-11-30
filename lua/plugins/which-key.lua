return {
  "folke/which-key.nvim",
  dependencies = {
    "nvim-mini/mini.nvim",
  },
  opts = {
    spec = {
      {
        mode = { "n", "x" },
        -- TODO: convert to nerdfont
        -- TODO: find ways to integrate better icons for groupings..
        { "<leader>a", group = "ai", icon = "A" },
        { "<leader>h", group = "harpoon", icon = "H" },
      },
    },
  },
}
-- TODO:: ai tool that consumes compiled keymap spec for q/a
-- TODO: get dif between branch and main into a register
