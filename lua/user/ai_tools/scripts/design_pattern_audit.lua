local registry = require("user.ai_tools.scripts.registry")

local M = {}

function M.execute()
  registry.run("design_pattern_audit")
end

return M
