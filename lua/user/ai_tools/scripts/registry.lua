local builders = require("user.ai_tools.context.builders")
local runner = require("user.ai_tools.runner")
local config = require("user.ai_tools.config")
local ui = require("user.ai_tools.ui")
local logger = require("user.ai_tools.logger")
local utils = require("user.ai_tools.utils")
local usage = require("user.ai_tools.usage")

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
    conversational = true,
    system = function(state)
      return ("You are an expert code reviewer. Think step by step, explain your thoughts, and help the user with the following GOAL: %s"):format(
        state.goal or ""
      )
    end,
    window = "split",
    context = {
      { type = "project_context" },
      { type = "user_prompt", prompt = "Enter the goal", save_as = "goal" },
      { type = "harpoon_files" },
    },
    format_prompt = concat_chunks,
  },
  git_diff_review = {
    id = "git_diff_review",
    title = "Git Diff Review",
    conversational = true,
    system = function(state)
      local goal = (state.goal and state.goal ~= "") and state.goal or "Summarize and review the staged changes."
      return ("You are a git assistant. Use the diff to help the user achieve the goal: %s"):format(goal)
    end,
    window = "split",
    context = {
      { type = "project_context" },
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
  keymap_query = {
    id = "keymap_query",
    title = "Keymap Query",
    system = [[You are an expert in Neovim and LazyVim configuration.
You will be given the user's local config files that define custom keymaps and plugin configurations.
Answer questions about what keymaps are available. Be specific: state the exact key combo and what it does.
LazyVim also provides many default keymaps not shown in local files (e.g. gd=definition, gr=references, K=hover, <leader>ud=toggle diagnostics) — include these when relevant.
Keep your answer concise and direct.]],
    window = "popup",
    context = {
      { type = "user_prompt", prompt = "Keymap question:", save_as = "question" },
      {
        type = "config_files",
        paths = {
          vim.fn.stdpath("config") .. "/lua/config/keymaps.lua",
        },
        glob_patterns = {
          vim.fn.stdpath("config") .. "/lua/plugins/*.lua",
        },
      },
    },
    format_prompt = function(chunks, state)
      return "QUESTION: " .. (state.question or "") .. "\n\n" .. concat_chunks(chunks)
    end,
  },
  design_patterns = {
    id = "design_patterns",
    title = "Design Patterns",
    conversational = true,
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
      { type = "project_context" },
      { type = "user_prompt", prompt = "Enter focus areas (optional):", save_as = "focus", allow_empty = true },
      { type = "harpoon_files" },
    },
    format_prompt = concat_chunks,
  },
  rewrite_context = {
    id = "rewrite_context",
    title = "Rewrite Context File",
    system = [[This file is a project context document that AI assistants read to provide accurate, consistent help without the user needing to repeat themselves. It covers project architecture, coding standards, technical stack, and workflows.

Edit it for signal quality — not brevity:
- PRESERVE all specific technical detail: architecture decisions, stack choices, design patterns, conventions, and workflows. Even minor specifics exist because someone needed to capture them. Do not cut them.
- REMOVE genuine redundancy: if the same fact is stated in two places, keep the clearer one and drop the duplicate
- REMOVE vague filler: generic statements that could apply to any project and add no real signal (e.g. "we write clean code", "testing is important")
- TIGHTEN prose: rewrite wordy explanations into direct statements without losing the underlying information
- KEEP section headings even if a section has little content — they signal intent

Length reduction is a side effect of removing noise, not a goal. The output may be similar in length to the input if the input is already specific.

Walk through your reasoning: explain what you kept, what you changed, and why. Then provide the full rewritten markdown at the end.]],
    window = "split",
    context = {
      { type = "context_file_raw" },
    },
    format_prompt = function(chunks, state)
      return "Rewrite the following project context file. Preserve all specific technical detail — only remove genuine redundancy and vague filler. Show your reasoning before presenting the rewritten file:\n\n" .. concat_chunks(chunks)
    end,
  },
  extract_context = {
    id = "extract_context",
    title = "Extract Context",
    conversational = true,
    system = "You are helping the user maintain a project context file that gives AI assistants background about their codebase. Be concise and factual. Output clean markdown.",
    window = "split",
    context = {
      { type = "project_context" },
      { type = "harpoon_files" },
    },
    format_prompt = function(chunks, state)
      return table.concat({
        "Analyze the code files below.",
        "Identify what should be ADDED to the project context file based on what is evident in the code but not yet captured in the existing project context (provided in the system message).",
        "Look for: architectural decisions, design patterns, cross-cutting concerns, conventions, and cross-repo relationships.",
        "Output ONLY the new markdown content to append. Be concise. Do not repeat anything already captured.",
        "",
        concat_chunks(chunks),
      }, "\n")
    end,
  },
  analyze_file = {
    id = "analyze_file",
    title = "Analyze File",
    conversational = true,
    system = "You are an expert code analyst. Think step by step and help the user reason about the provided file. Do not rewrite code unless explicitly asked.",
    window = "split",
    context = {
      { type = "user_prompt", prompt = "What do you want to know about this file?", save_as = "question" },
      { type = "active_file" },
    },
    format_prompt = function(chunks, state)
      return "QUESTION: " .. (state.question or "") .. "\n\n" .. concat_chunks(chunks)
    end,
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

---@param action string
---@param opts table|nil  { initial_state: table|nil }
function M.run(action, opts)
  usage.record(action)
  opts = opts or {}
  local entry = get_entry(action)
  local state = vim.deepcopy(opts.initial_state or {})
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
    if final_meta.project_context then
      system_message = system_message .. "\n\n" .. final_meta.project_context
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

    local base_runner_opts = {
      window_type = entry.window or cfg.window_type,
      provider = entry.provider,
      timeout = entry.timeout or cfg.timeout,
    }

    local function bind_capture(history, response_buf)
      ui.bind_capture(response_buf, function()
        local capture_messages = vim.list_extend(vim.deepcopy(history), {
          {
            role = "user",
            content = "From this conversation, extract any architectural decisions, design patterns, project-specific conventions, or cross-repo relationships worth preserving in the project context file. Output only the markdown content to append — concise, no commentary.",
          },
        })
        runner.run(vim.tbl_extend("force", base_runner_opts, {
          messages = capture_messages,
          window_type = "popup",
          on_success = function(response)
            local path = utils.find_or_default_context_path()
            local ok, err = utils.append_to_file(path, response)
            if ok then
              vim.notify("Captured to " .. vim.fn.fnamemodify(path, ":~:."), vim.log.levels.INFO)
            else
              ui.display_error("Capture failed: " .. (err or "unknown"))
            end
          end,
        }))
      end)
    end

    local bind_followup
    bind_followup = function(history, response_buf)
      ui.bind_followup(response_buf, function(user_input)
        local new_messages = vim.list_extend(vim.deepcopy(history), {
          { role = "user", content = user_input },
        })
        runner.run(vim.tbl_extend("force", base_runner_opts, {
          messages = new_messages,
          response_buf = response_buf,
          on_conversation_update = function(updated_history, buf)
            bind_followup(updated_history, buf)
            bind_capture(updated_history, buf)
          end,
        }))
      end)
    end

    runner.run(vim.tbl_extend("force", base_runner_opts, {
      prompt = prompt,
      system_message = system_message,
      on_conversation_update = entry.conversational and function(history, response_buf)
        bind_followup(history, response_buf)
        bind_capture(history, response_buf)
      end or nil,
    }))
  end)
end

function M.get_entries()
  return registry
end

return M
