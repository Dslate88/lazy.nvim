local no_complete_ft = {
  markdown = true,
  gitcommit = true,
  NeogitCommitMessage = true,
  text = true,
  help = true,
}

return {
  "saghen/blink.cmp",
  opts = {
    enabled = function()
      return not vim.b.blink_disable and not no_complete_ft[vim.bo.filetype]
    end,
  },
}
