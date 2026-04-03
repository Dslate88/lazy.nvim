local builders = require("user.ai_tools.context.builders")
local runner = require("user.ai_tools.runner")
local config = require("user.ai_tools.config")
local ui = require("user.ai_tools.ui")
local logger = require("user.ai_tools.logger")
local usage = require("user.ai_tools.usage")

local M = {}

local function concat_chunks(chunks)
  return table.concat(chunks, "\n\n")
end

local registry = {
  chat = {
    id = "chat",
    title = "Chat",
    system = [[You are a knowledgeable technical assistant.
Answer clearly and directly. Use markdown formatting: wrap code in fenced code blocks with the language identifier, use headers for multi-section answers, and use bullet lists for enumerations.
If the question is ambiguous, state your interpretation before answering.]],
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
    system = [[You are an expert code reviewer.
You will be given one or more source files. The user will state a specific goal in their message.

Review approach:
- Address the stated goal directly before covering anything else
- Identify bugs, incorrect assumptions, and edge cases
- Suggest improvements with brief rationale — do not rewrite entire files unless asked
- If the user seems confused or has a misconception, gently correct and educate them on the relevant concept before proceeding

Format: use markdown headers to separate concerns. Lead with a short summary paragraph.]],
    window = "split",
    context = {
      { type = "project_context" },
      { type = "user_prompt", prompt = "Enter the goal", save_as = "goal" },
      { type = "harpoon_files" },
    },
    format_prompt = function(chunks, state)
      -- files first, goal last (Anthropic long-context recommendation)
      local files_block = chunks[#chunks] or ""
      local goal = state.goal or ""
      return files_block .. "\n\nGOAL: " .. goal
    end,
  },
  git_diff_review = {
    id = "git_diff_review",
    title = "Git Diff Review",
    conversational = true,
    system = [[You are a senior software engineer reviewing staged code changes.
You will be given a git diff and optionally a review focus from the user.

Review the changes for:
- Logic errors and unintended side effects
- Missing edge case handling
- Code quality and clarity issues
- Unrelated changes that should be split into a separate commit
- Any secrets, debug artifacts, or leftover TODO comments

Structure your response: brief summary of what changed → findings by severity → concrete recommendations.
Ground your response in the project architecture context if provided.]],
    window = "split",
    context = {
      { type = "project_context" },
      {
        type = "user_prompt",
        prompt = "Review focus (optional):",
        save_as = "goal",
        allow_empty = true,
      },
      { type = "git_diff" },
    },
    format_prompt = function(chunks, state)
      local diff_block = chunks[#chunks] or ""
      local goal = state.goal or ""
      return diff_block .. (goal ~= "" and ("\n\nREVIEW FOCUS: " .. goal) or "")
    end,
  },
  commit_message = {
    id = "commit_message",
    title = "Commit Message",
    system = [[You are an expert at writing conventional commit messages.
Given a git diff of staged changes, output a single conventional commit message.

Format:
  <type>(<optional scope>): <short imperative summary>

  <optional body: explain WHY, not WHAT — only include if the summary is insufficient>

Rules:
- type must be one of: feat, fix, refactor, chore, docs, test, style, perf, ci, build
- summary line: 72 chars max, lowercase, no trailing period, imperative mood
- body: wrap at 72 chars, use blank line to separate from summary
- do NOT include a footer or breaking-change trailer unless the diff clearly warrants it
- output ONLY the commit message — no explanation, no markdown fences, no preamble]],
    window = "popup",
    context = {
      { type = "git_diff" },
    },
    format_prompt = function(chunks, _state)
      return chunks[1] or ""
    end,
  },
  branch_diff_review = {
    id = "branch_diff_review",
    title = "Branch Diff Review",
    conversational = true,
    system = [[You are a senior software engineer reviewing a feature branch.
You will be given the full diff between origin/main and the current branch HEAD.

Your analysis should cover:
- **Summary of changes**: a high-level overview of what was done, grouped by theme or area
- **Work completed**: concrete features, fixes, or refactors that appear finished
- **Potentially incomplete**: code that looks partial, stubbed, or inconsistent (TODO comments, missing tests, half-wired features)
- **Concerns**: logic errors, unintended side effects, or code quality issues worth addressing before merge
- **Suggested next steps**: what likely remains to bring this branch to a mergeable state

Be direct and specific. Reference file names and line-level details where relevant.
Ground your response in the project architecture context if provided.]],
    window = "split",
    context = {
      { type = "project_context" },
      {
        type = "git_diff",
        git_cmd = { "git", "diff", "origin/main...HEAD", "--no-color" },
      },
    },
    format_prompt = function(chunks, _state)
      return chunks[#chunks] or ""
    end,
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
      return chunks[#chunks] .. "\n\nQUESTION: " .. (state.question or "")
    end,
  },
  design_patterns = {
    id = "design_patterns",
    title = "Design Patterns",
    conversational = true,
    system = function(state)
      local focus_line = (state.focus and state.focus ~= "")
        and ("\n\nFocus areas for this session: " .. state.focus)
        or ""
      return [[You are a software design coach.
You will be given source files. Analyze them for structural and design quality using established software engineering principles and patterns.

For each observation:
1. Name the pattern or principle at play
2. Explain briefly why it applies or is violated in this specific code
3. Propose the smallest concrete change that would improve it
4. Note any tradeoffs

Adapt your recommendations to the idioms and conventions of whatever language the code is written in. Teach as you go. Prefer small, incremental suggestions over wholesale rewrites.]] .. focus_line
    end,
    window = "split",
    context = {
      { type = "project_context" },
      { type = "user_prompt", prompt = "Enter focus areas (optional):", save_as = "focus", allow_empty = true },
      { type = "harpoon_files" },
    },
    format_prompt = function(chunks, state)
      -- files first; focus is already in system message so drop it from prompt
      return chunks[#chunks] or ""
    end,
  },
  analyze_file = {
    id = "analyze_file",
    title = "Analyze File",
    conversational = true,
    system = [[You are an expert software engineer.
You will be given a source file and a specific question about it.

Answer the question first, then provide a structured breakdown of the file covering:
- **Purpose**: what this file does and its role in the broader system
- **Structure**: key components, functions, or sections and how they relate
- **Data flow**: how data enters, transforms, and exits
- **Dependencies**: what this file relies on and what relies on it
- **Notable behaviors**: side effects, error handling, or non-obvious logic worth knowing

Do not rewrite or refactor unless explicitly asked. Use markdown with fenced code blocks for any excerpts.]],
    window = "split",
    context = {
      { type = "user_prompt", prompt = "What do you want to know about this file?", save_as = "question" },
      { type = "active_file" },
    },
    format_prompt = function(chunks, state)
      return chunks[#chunks] .. "\n\nQUESTION: " .. (state.question or "")
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
      system_message = system_message .. string.format(
        "\n\n<project_context>\n<source>%s</source>\n<content>\n%s\n</content>\n</project_context>",
        final_meta.project_context_file or "architecture.md",
        final_meta.project_context
      )
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

      logger.info(vim.inspect(log_data))
    end

    local base_runner_opts = {
      window_type = entry.window or cfg.window_type,
      provider = entry.provider,
      timeout = entry.timeout or cfg.timeout,
    }

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
          end,
        }))
      end)
    end

    runner.run(vim.tbl_extend("force", base_runner_opts, {
      prompt = prompt,
      system_message = system_message,
      on_conversation_update = entry.conversational and function(history, response_buf)
        bind_followup(history, response_buf)
      end or nil,
    }))
  end)
end

function M.get_entries()
  return registry
end

return M
