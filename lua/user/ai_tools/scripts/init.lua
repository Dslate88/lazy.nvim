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

function M.keymap_query()
  registry.run("keymap_query")
end

function M.analyze_file()
  registry.run("analyze_file")
end

function M.open_context_file()
  local utils = require("user.ai_tools.utils")
  local path = utils.find_context_file()
  if not path then
    path = vim.fn.getcwd() .. "/.ai_context.md"
    utils.create_context_file(path)
  end
  vim.cmd("vsplit " .. vim.fn.fnameescape(path))
end

function M.extract_context()
  registry.run("extract_context")
end

function M.rewrite_context()
  registry.run("rewrite_context")
end

function M.view_keymap_details()
  local path = vim.fn.stdpath("config") .. "/lua/user/ai_tools/ai_reference.md"
  vim.cmd("vsplit " .. vim.fn.fnameescape(path))
end

return M
