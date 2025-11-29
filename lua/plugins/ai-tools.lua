return {
  -- dependencies
  { "nvim-lua/plenary.nvim" },
  { "ThePrimeagen/harpoon", branch = "harpoon2" },

  {
    name = "ai-tools-local",
    dir = vim.fn.stdpath("config") .. "/lua/user/ai_tools",
    lazy = true,
    opts = {
      default_provider = "openai",
      default_system_message = "You are a helpful assistant.",
      window_type = "popup",
      enable_history = true,
      timeout = 60000,
      providers = {
        openai = { api_key = os.getenv("OPENAI_API_KEY"), model = "gpt-4o" },
        azure = {
          api_key = os.getenv("AZURE_OPENAI_API_KEY"),
          endpoint = os.getenv("AZURE_OPENAI_ENDPOINT"),
          deployment_id = "gpt-4o",
          model = "gpt-4o",
        },
      },
    },
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
