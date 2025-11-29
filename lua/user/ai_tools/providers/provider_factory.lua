local config = require("user.ai_tools.config")

local M = {}
local cache = {}

function M.get_provider(provider_name)
  local cfg = config.get_config()
  local name = provider_name or cfg.default_provider

  if not cfg.providers[name] then
    error("Invalid provider: " .. name)
  end

  if cache[name] then
    return cache[name]
  end

  local ok, provider_module = pcall(require, "user.ai_tools.providers." .. name)
  if not ok then
    error("Failed to load provider: " .. name .. ". Error: " .. provider_module)
  end

  cache[name] = provider_module
  return provider_module
end

return M
