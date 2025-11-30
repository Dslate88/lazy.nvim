local provider_factory = require("user.ai_tools.providers.provider_factory")
local config = require("user.ai_tools.config")
local ui = require("user.ai_tools.ui")

local M = {}

---@param opts table
---  - prompt: string
---  - provider: string|nil
---  - system_message: string|nil
---  - window_type: string|nil
---  - timeout: number|nil
---  - on_success: fun(response:string, raw:table)|nil
function M.run(opts)
  local cfg = config.get_config()
  local provider_name = opts.provider or cfg.default_provider
  local provider_cfg = cfg.providers[provider_name]

  if not provider_cfg then
    ui.display_error("Provider not configured: " .. provider_name)
    return
  end

  local provider = provider_factory.get_provider(provider_name)
  local settings = vim.tbl_deep_extend("force", {}, provider_cfg, {
    system_message = opts.system_message or cfg.default_system_message,
    timeout = opts.timeout or cfg.timeout,
  })

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
      ui.display_response(response, window_type)

      if opts.on_success then
        opts.on_success(response, result)
      end
    end)
  )
end

return M
