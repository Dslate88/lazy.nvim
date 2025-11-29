local config = require("user.ai_tools.config")

local M = {}

function M.get_provider(provider_name)
	local cfg = config.get_config()
	provider_name = provider_name or cfg.default_provider

	if not cfg.providers[provider_name] then
		error("Invalid provider: " .. provider_name)
	end

	local success, provider_module = pcall(require, "user.ai_tools.providers." .. provider_name)

	if not success then
		error("Failed to load provider: " .. provider_name .. ". Error: " .. provider_module)
	end

	return provider_module
end

return M
