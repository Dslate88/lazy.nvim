return {
  -- TODO: build quickfix ai_tools script (similiar to harpoon_list)
  "snacks.nvim",
  opts = {
    dashboard = { enabled = false },
    animate = { enabled = false },
    scroll = { enabled = false },
  },
  keys = {
    -- NOTE: when picker is open CTRL + Q sends all files "tab" actioned to the qflist
    {
      "<leader>sv",
      function()
        local picker = Snacks.picker.current or Snacks.picker.get()[1]
        if not picker then
          return Snacks.notify.warn("No active picker")
        end
        Snacks.picker.actions.qflist_all(picker)
      end,
      desc = "Send all picker items to quickfix",
    },
    -- disable: pick files
    { "<leader><space>", false },

    -- disable: recent file picker
    { "<leader>fr", false },
    { "<leader>fR", false },

    -- disable: git diff by hunk
    { "<leader>gd", false },

    -- disable: git diff vs origin
    { "<leader>gD", false },

    -- disable: git status
    { "<leader>gs", false },

    -- disable: git stashes
    { "<leader>gS", false },

    -- change a keymap
    -- { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
  },
}
