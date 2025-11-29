local utils = require("user.ai_tools.utils")
local runner = require("user.ai_tools.runner")
local ui = require("user.ai_tools.ui")
local marked = require("user.ai_tools.harpoon")
local config = require("user.ai_tools.config")

local M = {}

local script_config = {
  action = "harpoon_review",
  window_type = "split",
  enable_history = true,
  system_message = "You are an expert code reviewer. Think step by step, explain your thoughts, and help the user with the following GOAL: ",
  max_file_bytes = 200 * 1024,
}

local function read_files(files)
  local chunks = {}
  for _, file in ipairs(files) do
    local content, err = utils.read_file(file.filename)
    if not content then
      return nil, "Error reading file: " .. err
    end
    if script_config.max_file_bytes and #content > script_config.max_file_bytes then
      content = content:sub(1, script_config.max_file_bytes) .. "\n\n[Truncated due to size]"
    end
    table.insert(chunks, "FILE NAME BEGIN: " .. file.filename .. "\n")
    table.insert(chunks, "FILE CONTENT BEGIN:\n" .. content .. "\nFILE CONTENT END\n")
  end
  return table.concat(chunks, "\n")
end

local function build_meta(goal, files)
  return {
    goal = goal,
    files = files,
    timestamp = os.time(),
  }
end

function M.execute()
  ui.get_user_prompt({
    prompt = "Enter the goal:",
    enable_history = script_config.enable_history,
    action = script_config.action,
  }, function(goal)
    if goal == "" then
      print("Goal cannot be empty.")
      return
    end

    local files = marked.get_marked_files()
    if #files == 0 then
      print("No marked files found during execution.")
      return
    end

    local prompt, err = read_files(files)
    if not prompt then
      ui.display_error(err or "Failed to build prompt from files.")
      return
    end

    local meta = build_meta(goal, files)
    local cfg = config.get_config()

    runner.run({
      action = script_config.action,
      prompt = prompt,
      system_message = script_config.system_message .. goal,
      window_type = script_config.window_type,
      enable_history = script_config.enable_history,
      timeout = cfg.timeout,
      meta = meta,
    })
  end)
end

return M
