local builders = require("user.ai_tools.context.builders")
local utils = require("user.ai_tools.utils")

local M = {}

local function build_prompt(goal, opts)
  local builder_err
  local builder_result
  builders.harpoon_files(opts or {}, {}, function(err, result)
    builder_err = err
    builder_result = result
  end)

  if builder_err then
    return nil, builder_err
  end

  local chunks = {}
  if goal and goal ~= "" then
    table.insert(chunks, "GOAL: " .. goal)
  end

  if builder_result and builder_result.prompt and builder_result.prompt ~= "" then
    table.insert(chunks, builder_result.prompt)
  end

  return table.concat(chunks, "\n\n"), builder_result and builder_result.meta or {}
end

function M.execute(goal, opts)
  local prompt, err_or_meta = build_prompt(goal or "fill out goal", opts)
  if not prompt then
    vim.notify(err_or_meta or "Failed to generate prompt", vim.log.levels.ERROR)
    return
  end

  utils.copy_to_clipboard(prompt)
  return prompt
end

return M
