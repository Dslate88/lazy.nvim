local curl = require("plenary.curl")
local config = require("user.ai_tools.config")

local M = {}

local ENDPOINT_NAME = "databricks-claude-sonnet-4-6"
local MAX_TOKENS = 20000

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
    return nil, "Missing Databricks api_key (DATABRICKS_TOKEN)"
  end
  if not settings.host then
    return nil, "Missing Databricks host (DATABRICKS_HOST)"
  end
  return true
end

function M.send_request(prompt, settings, callback)
  local merged_settings = vim.tbl_deep_extend("force", {
    api_key = config.providers.databricks_claude.api_key,
    host = config.providers.databricks_claude.host,
  }, settings or {})

  local ok, err = validate_settings(merged_settings)
  if not ok then
    if callback then
      callback(nil, err)
      return
    end
    return nil, err
  end

  local url = merged_settings.host .. "/serving-endpoints/" .. ENDPOINT_NAME .. "/invocations"

  local messages = merged_settings.messages or {
    { role = "system", content = merged_settings.system_message or config.default_system_message },
    { role = "user", content = prompt },
  }

  local body = vim.json.encode({
    messages = messages,
    max_tokens = MAX_TOKENS,
  })

  local function handle(res)
    local result, parse_err = parse_response(res)
    local choice = result and result.choices and result.choices[1]
    if not parse_err and not choice then
      parse_err = "No choices returned from Databricks Claude"
    end
    if callback then
      callback(result, parse_err)
      return
    end
    return result, parse_err
  end

  local request_opts = {
    headers = {
      ["Authorization"] = "Bearer " .. merged_settings.api_key,
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
