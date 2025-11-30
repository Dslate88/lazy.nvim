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
        "<leader>ap",
        function()
          require("user.ai_tools.scripts").design_pattern_audit()
        end,
        desc = "Design Pattern Audit",
      },
    },
    config = function(_, opts)
      require("user.ai_tools.config").setup(opts)
    end,
  },
}
