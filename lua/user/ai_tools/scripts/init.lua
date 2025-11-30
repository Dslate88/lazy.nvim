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

function M.design_pattern_audit()
  registry.run("design_pattern_audit")
end

return M
