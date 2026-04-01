return {
  "saghen/blink.cmp",
  opts = {
    enabled = function()
      return not vim.b.blink_disable
    end,
  },
}
