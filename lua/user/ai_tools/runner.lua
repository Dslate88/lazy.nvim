local provider_factory = require("user.ai_tools.providers.provider_factory")
local config = require("user.ai_tools.config")
local ui = require("user.ai_tools.ui")
local logger = require("user.ai_tools.logger")

local M = {}

---@param opts table
---  - prompt: string|nil                 used when messages is absent
---  - messages: table|nil                full history; overrides prompt + system_message
---  - system_message: string|nil
---  - provider: string|nil
---  - window_type: string|nil
---  - timeout: number|nil
---  - response_buf: number|nil           existing buffer to append a follow-up into
---  - on_success: fun(response:string, raw:table)|nil
---  - on_conversation_update: fun(messages:table, response_buf:number)|nil
function M.run(opts)
  local cfg = config.get_config()
  local provider_name = opts.provider or cfg.default_provider

  local ok, provider = pcall(provider_factory.get_provider, provider_name)
  if not ok then
    ui.display_error(provider)
    return
  end

  local provider_cfg = cfg.providers[provider_name]
  local system_message = opts.system_message or cfg.default_system_message

  local outgoing_messages = opts.messages or {
    { role = "system", content = system_message },
    { role = "user", content = opts.prompt },
  }

  local settings = vim.tbl_deep_extend("force", {}, provider_cfg, {
    messages = outgoing_messages,
    timeout = opts.timeout or cfg.timeout,
  })

  if cfg.debug then
    local ok, encoded = pcall(vim.json.encode, outgoing_messages)
    logger.info("runner.run outgoing_messages: " .. (ok and encoded or tostring(encoded)))
  end

  provider.send_request(
    opts.prompt,
    settings,
    vim.schedule_wrap(function(result, err)
      if err then
        ui.display_error(err)
        return
      end

      local choice = result and result.choices and result.choices[1]
      local response = choice and choice.message and choice.message.content
      if not response or response == "" then
        ui.display_error("Empty response from provider: " .. provider_name)
        return
      end

      local window_type = opts.window_type or cfg.window_type
      local response_buf = ui.display_response(response, window_type, opts.response_buf)

      local updated_messages = vim.list_extend(vim.deepcopy(outgoing_messages), {
        { role = "assistant", content = response },
      })

      if opts.on_conversation_update then
        opts.on_conversation_update(updated_messages, response_buf)
      end

      if opts.on_success then
        opts.on_success(response, result)
      end
    end)
  )
end

return M
