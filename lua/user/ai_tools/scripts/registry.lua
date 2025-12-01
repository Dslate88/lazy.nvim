local builders = require("user.ai_tools.context.builders")
local runner = require("user.ai_tools.runner")
local config = require("user.ai_tools.config")
local ui = require("user.ai_tools.ui")
local logger = require("user.ai_tools.logger")

local M = {}

local function concat_chunks(chunks)
  return table.concat(chunks, "\n\n")
end

local registry = {
  chat = {
    id = "chat",
    title = "Chat",
    system = "Formatting re-enabled - code output should be wrapped in markdown, and use markdown to make text easier to read.",
    window = "popup",
    context = {
      { type = "user_prompt", prompt = "Enter your prompt:", save_as = "prompt" },
    },
    format_prompt = concat_chunks,
  },
  harpoon_review = {
    id = "harpoon_review",
    title = "Harpoon Review",
    system = function(state)
      return ("You are an expert code reviewer. Think step by step, explain your thoughts, and help the user with the following GOAL: %s"):format(
        state.goal or ""
      )
    end,
    window = "split",
    context = {
      { type = "user_prompt", prompt = "Enter the goal", save_as = "goal" },
      { type = "harpoon_files" },
    },
    format_prompt = concat_chunks,
  },
  git_diff_review = {
    id = "git_diff_review",
    title = "Git Diff Review",
    system = function(state)
      local goal = (state.goal and state.goal ~= "") and state.goal or "Summarize and review the staged changes."
      return ("You are a git assistant. Use the diff to help the user achieve the goal: %s"):format(goal)
    end,
    window = "split",
    context = {
      {
        type = "user_prompt",
        prompt = "Describe your goal (commit message, review focus, etc.):",
        save_as = "goal",
        allow_empty = true,
      },
      { type = "git_diff" },
    },
    format_prompt = concat_chunks,
  },
  design_patterns = {
    id = "design_patterns",
    title = "Design Patterns",
    system = function(state)
      local focus = state.focus and state.focus ~= "" and (" Focus areas: " .. state.focus) or ""
      return table.concat({
        "You are a design patterns coach drawing on 'Design Patterns: Elements of Reusable Object-Oriented Software'.",
        "Analyze the provided code for opportunities to apply or improve patterns. Call out misuses or missing abstractions.",
        "Teach as you go: briefly explain why a pattern fits, tradeoffs, and small steps to implement it.",
        focus,
      }, " ")
    end,
    window = "split",
    context = {
      { type = "user_prompt", prompt = "Enter focus areas (optional):", save_as = "focus", allow_empty = true },
      { type = "harpoon_files" },
    },
    format_prompt = concat_chunks,
  },
}

local function get_entry(action)
  local entry = registry[action]
  if not entry then
    error("Unknown ai_tools action: " .. tostring(action))
  end
  return entry
end

local function run_builders(entry, idx, state, chunks, meta, cb)
  local item = entry.context[idx]
  if not item then
    cb(nil, state, chunks, meta)
    return
  end

  local builder = builders[item.type]
  if not builder then
    cb("Unknown context builder: " .. tostring(item.type))
    return
  end

  builder(vim.tbl_deep_extend("force", {}, item), state, function(err, result)
    if err then
      cb(err)
      return
    end

    if result then
      if result.prompt then
        table.insert(chunks, result.prompt)
      end
      if result.meta then
        meta = vim.tbl_deep_extend("force", meta, result.meta)
      end
    end

    run_builders(entry, idx + 1, state, chunks, meta, cb)
  end)
end

function M.run(action)
  local entry = get_entry(action)
  local state = {}
  local chunks = {}
  local meta = {}

  run_builders(entry, 1, state, chunks, meta, function(err, final_state, final_chunks, final_meta)
    if err then
      ui.display_error(err)
      return
    end

    local prompt = entry.format_prompt and entry.format_prompt(final_chunks, final_state) or concat_chunks(final_chunks)
    if not prompt or prompt == "" then
      ui.display_error("Prompt cannot be empty.")
      return
    end

    local system_message = type(entry.system) == "function" and entry.system(final_state) or entry.system
    if not system_message or system_message == "" then
      system_message = config.default_system_message
    end
    local cfg = config.get_config()

    if cfg.debug then
      local log_data = {
        entry = {
          id = entry.id,
          title = entry.title,
          context = entry.context,
          window = entry.window,
          provider = entry.provider,
        },
        state = final_state,
        chunks = final_chunks,
        meta = final_meta,
        prompt = prompt,
        system_message = system_message,
      }

      local ok, encoded = pcall(vim.json.encode, log_data)
      logger.info(ok and encoded or ("registry.run payload encode failed: " .. tostring(encoded)))
    end

    runner.run({
      prompt = prompt,
      system_message = system_message,
      window_type = entry.window or cfg.window_type,
      provider = entry.provider,
      timeout = entry.timeout or cfg.timeout,
    })
  end)
end

function M.get_entries()
  return registry
end

return M
