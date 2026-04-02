return {
  "folke/which-key.nvim",
  dependencies = {
    "nvim-mini/mini.nvim",
  },
  opts = {
    spec = {
      {
        mode = { "n", "x" },
        { "<leader>a", group = "ai", icon = "󰧑" },
        { "<leader>h", group = "harpoon", icon = "H" },
        { "<leader>ac", icon = "󰭹" }, -- Chat
        { "<leader>ar", icon = "󰓡" }, -- Harpoon Goal
        { "<leader>ad", icon = "󰙨" }, -- Design Patterns
        { "<leader>ag", icon = "󰊢" }, -- Git Diff
        { "<leader>ao", icon = "󰑓" }, -- Organize Context File
        { "<leader>ai", icon = "󰈙" }, -- Open Context File
        { "<leader>ae", icon = "󰄾" }, -- Extract Context
        { "<leader>ak", icon = "󰌌" }, -- Keymap Query
        { "<leader>as", icon = "󰍉" }, -- Analyze File
        { "<leader>at", icon = "󱁢" }, -- Terraform Docs
        { "<leader>ap", icon = "󱜻" }, -- Prompt Gen
        { "<leader>aR", icon = "󰋼" }, -- AI Reference
        { "<leader>aU", icon = "󰻿" }, -- Usage Summary
        { "<leader>ah", icon = "󰐕" }, -- Harpoon add from picker
        { "<leader>aH", icon = "󰮍" }, -- Harpoon replace from picker
      },
    },
  },
}
-- TODO:: ai tool that consumes compiled keymap spec for q/a
-- TODO: get dif between branch and main into a register
