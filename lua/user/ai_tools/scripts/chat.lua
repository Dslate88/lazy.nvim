local provider_factory = require("user.ai_tools.providers.provider_factory")
local history = require("user.ai_tools.history")
local global_config = require("user.ai_tools.config")
local ui = require("user.ai_tools.ui")

local M = {}

local config = {
	provider = "openai",
	window_type = "popup",
	enable_history = true,
	system_message = "Formatting re-enabled - code output should be wrapped in markdown, and use markdown to make text easer to read too.",
}

function M.execute()
	ui.get_user_prompt("Enter your prompt:", config.enable_history, function(prompt)
		if prompt == "" then
			print("Prompt cannot be empty.")
			return
		end

		-- Use the provider specified in the script's config
		local provider = provider_factory.get_provider(config.provider)
		local cfg = global_config.get_config()
		local provider_settings = vim.tbl_deep_extend("force", {}, cfg.providers[config.provider], {
			system_message = config.system_message or cfg.default_system_message,
			timeout = cfg.timeout,
		})

		provider.send_request(prompt, provider_settings, vim.schedule_wrap(function(result, err)
			if err then
				ui.display_error(err)
				return
			end

			local response = result.choices[1].message.content
			ui.display_response(response, config.window_type)

			if config.enable_history then
				history.add(prompt, response)
			end
		end))
	end)
end

return M
