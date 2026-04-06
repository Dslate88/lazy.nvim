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
        "<leader>aG",
        function()
          require("user.ai_tools.scripts").commit_message()
        end,
        desc = "Generate commit message",
      },
      {
        "<leader>ab",
        function()
          require("user.ai_tools.scripts").branch_diff_review()
        end,
        desc = "Branch Diff",
      },
      {
        "<leader>ai",
        function()
          require("user.ai_tools.scripts").open_arch_file()
        end,
        desc = "Open architecture.md",
      },
      {
        "<leader>ak",
        function()
          require("user.ai_tools.scripts").keymap_query()
        end,
        desc = "Keymap Query",
      },
      {
        "<leader>as",
        function()
          require("user.ai_tools.scripts").analyze_file()
        end,
        desc = "Analyze File",
      },
      {
        "<leader>at",
        function()
          require("user.terraform_docs").lookup()
        end,
        desc = "Terraform Docs",
      },
      {
        "<leader>ap",
        function()
          require("user.prompt_gen").execute()
        end,
        desc = "Prompt Gen",
      },
      {
        "<leader>aR",
        function()
          require("user.ai_tools.scripts").view_keymap_details()
        end,
        desc = "View Keymap Details",
      },
      {
        "<leader>aU",
        function()
          require("user.ai_tools.usage").summary()
        end,
        desc = "Usage Summary",
      },
      {
        "<leader>aA",
        function()
          require("user.arch_gen").run()
        end,
        desc = "Generate architecture.md",
      },
      {
        "<leader>aP",
        function()
          require("user.ai_tools.scripts").power_prompt()
        end,
        desc = "Power Prompt",
      },
    },
    config = function(_, opts)
      require("user.ai_tools.config").setup(opts)
    end,
  },
}
