local function picker_to_harpoon(clear_first)
  local picker = Snacks.picker.current or Snacks.picker.get()[1]
  if not picker then
    return Snacks.notify.warn("No active picker")
  end
  local items = picker:selected({ fallback = true })
  picker:close()
  local list = require("harpoon"):list()
  if clear_first then
    list:clear()
  end
  local before = list:length()
  for _, item in ipairs(items) do
    local path = Snacks.picker.util.path(item)
    if path then
      list:add(list.config.create_list_item(list.config, path))
    end
  end
  local added = list:length() - before
  local verb = clear_first and "replaced list with" or "added"
  Snacks.notify(("Harpoon: %s %d file%s"):format(verb, added, added == 1 and "" or "s"))
end

return {
  -- TODO: build quickfix ai_tools script (similiar to harpoon_list)
  "snacks.nvim",
  opts = {
    dashboard = { enabled = false },
    animate = { enabled = false },
    scroll = { enabled = false },
    explorer = { enabled = false },
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
    {
      "<leader>ah",
      function() picker_to_harpoon(false) end,
      desc = "Harpoon add from picker",
    },
    {
      "<leader>aH",
      function() picker_to_harpoon(true) end,
      desc = "Harpoon replace from picker",
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

  },
}
