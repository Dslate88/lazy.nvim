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
          require("user.ai_tools.scripts.chat").execute()
        end,
        desc = "AI Chat",
      },
      {
        "<leader>ar",
        function()
          require("user.ai_tools.scripts.harpoon_list").execute()
        end,
        desc = "AI Review Harpoon",
      },
    },
    config = function(_, opts)
      require("user.ai_tools.config").setup(opts)
    end,
  },
}
