local curl = require("plenary.curl")
local config = require("user.ai_tools.config")

local M = {}

local function parse_response(res)
	if not res then
		return nil, "No response received"
	end

	local ok, result = pcall(vim.json.decode, res.body or "")
	if not ok then
		return nil, "Failed to decode response"
	end

	if res.status ~= 200 then
		return nil, (result.error and result.error.message) or ("HTTP " .. tostring(res.status))
	end

	return result, nil
end

function M.send_request(prompt, settings, callback)
	local system_message = settings.system_message or "You are a helpful AI assistant"

	local deployment_id = settings.deployment_id or config.providers.azure.deployment_id
	local endpoint = settings.endpoint or config.providers.azure.endpoint
	local url = endpoint .. "/openai/deployments/" .. deployment_id .. "/chat/completions?api-version=2024-12-01-preview"

	local body = vim.json.encode({
		model = settings.model,
		messages = {
			{ role = "system", content = system_message },
			{ role = "user", content = prompt },
		},
	})

	local function handle(res)
		local result, err = parse_response(res)
		if callback then
			callback(result, err)
			return
		end
		return result, err
	end

	local request_opts = {
		headers = {
			["api-key"] = config.providers.azure.api_key,
			["Content-Type"] = "application/json",
		},
		body = body,
		timeout = settings.timeout or config.timeout,
	}

	if callback then
		curl.post(url, vim.tbl_extend("force", request_opts, { callback = handle }))
		return
	end

	local res = curl.post(url, request_opts)
	return handle(res)
end

return M
