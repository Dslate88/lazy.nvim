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

local function validate_settings(settings)
  if not settings or not settings.api_key then
    return nil, "Missing Azure OpenAI api_key"
  end
  if not settings.endpoint then
    return nil, "Missing Azure OpenAI endpoint"
  end
  if not settings.deployment_id then
    return nil, "Missing Azure OpenAI deployment_id"
  end
  return true
end

function M.send_request(prompt, settings, callback)
  local merged_settings = vim.tbl_deep_extend("force", {
    api_key = config.providers.azure.api_key,
    endpoint = config.providers.azure.endpoint,
    deployment_id = config.providers.azure.deployment_id,
  }, settings or {})

  local ok, err = validate_settings(merged_settings)
  if not ok then
    if callback then
      callback(nil, err)
      return
    end
    return nil, err
  end

  local system_message = merged_settings.system_message or config.default_system_message
  local url = merged_settings.endpoint
    .. "/openai/deployments/"
    .. merged_settings.deployment_id
    .. "/chat/completions?api-version=2024-12-01-preview"

  local body = vim.json.encode({
    model = merged_settings.model,
    messages = {
      { role = "system", content = system_message },
      { role = "user", content = prompt },
    },
  })

  local function handle(res)
    local result, parse_err = parse_response(res)
    local choice = result and result.choices and result.choices[1]
    if not parse_err and not choice then
      parse_err = "No choices returned from Azure OpenAI"
    end
    if callback then
      callback(result, parse_err)
      return
    end
    return result, parse_err
  end

  local request_opts = {
    headers = {
      ["api-key"] = merged_settings.api_key,
      ["Content-Type"] = "application/json",
    },
    body = body,
    timeout = merged_settings.timeout or config.timeout,
  }

  if callback then
    curl.post(url, vim.tbl_extend("force", request_opts, { callback = handle }))
    return
  end

  local res = curl.post(url, request_opts)
  return handle(res)
end

return M
