return {
  "saghen/blink.cmp",
  opts = {
    enabled = function()
      return not vim.b.blink_disable and vim.bo.filetype ~= "markdown"
    end,
  },
}
