local registry = require("user.ai_tools.scripts.registry")

local M = {}

function M.run(action)
  registry.run(action)
end

function M.chat()
  registry.run("chat")
end

function M.harpoon_review()
  registry.run("harpoon_review")
end

function M.design_patterns()
  registry.run("design_patterns")
end

function M.get_diff_review()
  registry.run("git_diff_review")
end

function M.commit_message()
  registry.run("commit_message")
end

function M.branch_diff_review()
  registry.run("branch_diff_review")
end

function M.keymap_query()
  registry.run("keymap_query")
end

function M.analyze_file()
  registry.run("analyze_file")
end

function M.open_arch_file()
  local utils = require("user.ai_tools.utils")
  local path = utils.find_arch_file()
  if not path then
    vim.notify("[ai_tools] No architecture.md found. Run <leader>aA to generate one.", vim.log.levels.WARN)
    return
  end
  vim.cmd("vsplit " .. vim.fn.fnameescape(path))
end

function M.view_keymap_details()
  local path = vim.fn.stdpath("config") .. "/lua/user/ai_tools/ai_reference.md"
  vim.cmd("vsplit " .. vim.fn.fnameescape(path))
end

return M
