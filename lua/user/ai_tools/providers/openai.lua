local config = require("user.ai_tools.config")
local curl = require("plenary.curl")

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
	local body = vim.json.encode({
		model = settings.model,
		messages = {
			{ role = "system", content = settings.system_message },
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

	if callback then
		curl.post("https://api.openai.com/v1/chat/completions", {
			headers = {
				["Authorization"] = "Bearer " .. settings.api_key,
				["Content-Type"] = "application/json",
			},
			body = body,
			timeout = settings.timeout or config.timeout,
			callback = handle,
		})
		return
	end

	local res = curl.post("https://api.openai.com/v1/chat/completions", {
		headers = {
			["Authorization"] = "Bearer " .. settings.api_key,
			["Content-Type"] = "application/json",
		},
		body = body,
		timeout = settings.timeout or config.timeout,
	})

	return handle(res)
end

return M
