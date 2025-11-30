local registry = require("user.ai_tools.scripts.registry")

local M = {}

function M.execute()
  registry.run("harpoon_review")
end

return M
