local M = {}

local defaults = {
	default_provider = "openai",
	default_system_message = "You are a helpful assistant.",
	window_type = "popup",
	enable_history = false,
	timeout = 60000, -- 60 seconds
	providers = {
		openai = {
			api_key = os.getenv("OPENAI_API_KEY"),
			model = "gpt-4o",
			-- model = "gpt-4o-mini",
		},
		azure = {
			api_key = os.getenv("AZURE_OPENAI_API_KEY"),
			endpoint = os.getenv("AZURE_OPENAI_ENDPOINT"),
			deployment_id = "gpt-4o",
		},
	},
}

local config = vim.deepcopy(defaults)

local function apply_config()
	for key, value in pairs(config) do
		M[key] = value
	end
end

local function validate(cfg)
	vim.validate({
		default_provider = { cfg.default_provider, "string" },
		default_system_message = { cfg.default_system_message, "string" },
		window_type = { cfg.window_type, "string" },
		enable_history = { cfg.enable_history, "boolean" },
		timeout = { cfg.timeout, "number" },
		providers = { cfg.providers, "table" },
	})

	if not cfg.providers[cfg.default_provider] then
		error("default_provider '" .. cfg.default_provider .. "' is not defined in providers")
	end
end

---Merge user opts with defaults.
---@param opts table|nil
function M.setup(opts)
	config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
	validate(config)
	apply_config()
	return config
end

function M.get_config()
	return config
end

function M.get_provider(name)
	local cfg = config
	local provider_name = name or cfg.default_provider
	local provider = cfg.providers[provider_name]
	if not provider then
		error("Invalid provider: " .. tostring(provider_name))
	end
	return provider, provider_name
end

apply_config()

return M
