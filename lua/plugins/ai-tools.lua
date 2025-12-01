return {
  -- dependencies
  { "nvim-lua/plenary.nvim" },
  { "ThePrimeagen/harpoon", branch = "harpoon2" },

  {
    name = "ai-tools-local",
    dir = vim.fn.stdpath("config") .. "/lua/user/ai_tools",
    lazy = true,
    opts = require("user.ai_tools.config").defaults,
    keys = {
      {
        "<leader>ac",
        function()
          require("user.ai_tools.scripts").chat()
        end,
        desc = "Chat",
      },
      {
        "<leader>ar",
        function()
          require("user.ai_tools.scripts").harpoon_review()
        end,
        desc = "Harpoon Goal",
      },
      {
        "<leader>ad",
        function()
          require("user.ai_tools.scripts").design_patterns()
        end,
        desc = "Design Patterns",
      },
      {
        "<leader>ag",
        function()
          require("user.ai_tools.scripts").get_diff_review()
        end,
        desc = "Git Diff",
      },
      {
        "<leader>ap",
        function()
          require("user.prompt_gen").execute()
        end,
        desc = "Prompt Gen",
      },
    },
    config = function(_, opts)
      require("user.ai_tools.config").setup(opts)
    end,
  },
}
