local runner = require("user.ai_tools.runner")
local ui = require("user.ai_tools.ui")

local M = {}

local config = {
  action = "chat",
  window_type = "popup",
  enable_history = true,
  system_message = "Formatting re-enabled - code output should be wrapped in markdown, and use markdown to make text easier to read.",
}

function M.execute()
  ui.get_user_prompt({
    prompt = "Enter your prompt:",
    enable_history = config.enable_history,
    action = config.action,
  }, function(prompt)
    if prompt == "" then
      print("Prompt cannot be empty.")
      return
    end

    runner.run({
      action = config.action,
      prompt = prompt,
      system_message = config.system_message,
      window_type = config.window_type,
      enable_history = config.enable_history,
    })
  end)
end

return M
