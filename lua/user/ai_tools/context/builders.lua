local utils = require("user.ai_tools.utils")
local ui = require("user.ai_tools.ui")
local marked = require("user.ai_tools.harpoon")

local M = {}

local function file_block(path, content)
  return "FILE NAME BEGIN: " .. path .. "\nFILE CONTENT BEGIN:\n" .. content .. "\nFILE CONTENT END\n"
end

-- opts: prompt (string), allow_empty (bool), save_as (string)
function M.user_prompt(opts, state, cb)
  local label = opts.prompt or "Enter input:"
  ui.get_user_prompt({
    prompt = label,
  }, function(input)
    if (not opts.allow_empty) and (not input or input == "") then
      cb("Input cannot be empty.")
      return
    end
    state[opts.save_as or "user_input"] = input
    local result = {
      meta = { [opts.save_as or "user_input"] = input },
    }
    if input and input ~= "" then
      result.prompt = input
    end
    cb(nil, result)
  end)
end

-- opts: table|nil
function M.harpoon_files(opts, state, cb)
  local files = marked.get_marked_files()
  if #files == 0 then
    cb("No marked files found during execution.")
    return
  end

  local chunks = {}
  local meta = { files = files }

  for _, file in ipairs(files) do
    local content, err = utils.read_file(file.filename)
    if not content then
      cb("Error reading file: " .. (err or "unknown error"))
      return
    end
    table.insert(chunks, file_block(file.filename, content))
  end

  cb(nil, {
    prompt = table.concat(chunks, "\n"),
    meta = meta,
  })
end

-- opts: include_unstaged (bool), git_cmd (table|nil), cwd (string|nil)
function M.git_diff(opts, state, cb)
  local include_unstaged = opts.include_unstaged or false
  local cmd = opts.git_cmd
    or (include_unstaged and { "git", "diff", "--no-color" } or { "git", "diff", "--cached", "--no-color" })

  vim.system(cmd, { text = true, cwd = opts.cwd }, function(obj)
    if obj.code ~= 0 then
      local stderr = (obj.stderr or ""):gsub("%s+$", "")
      cb("Git diff failed: " .. (stderr ~= "" and stderr or ("exit code " .. tostring(obj.code))))
      return
    end

    local stdout = obj.stdout or ""
    if stdout == "" then
      cb(include_unstaged and "No unstaged changes found." or "No staged changes found.")
      return
    end

    local prompt = stdout

    cb(nil, {
      prompt = table.concat({
        "GIT DIFF BEGIN",
        prompt,
        "GIT DIFF END",
      }, "\n"),
      meta = {
        git_cmd = cmd,
        include_unstaged = include_unstaged,
        bytes = #stdout,
      },
    })
  end)
end

-- opts: paths (string[]), glob_patterns (string[])
function M.config_files(opts, _state, cb)
  local chunks = {}
  local all_paths = {}

  for _, p in ipairs(opts.paths or {}) do
    local content = utils.read_file(p)
    if content then
      table.insert(chunks, file_block(p, content))
      table.insert(all_paths, p)
    end
  end
  for _, pattern in ipairs(opts.glob_patterns or {}) do
    for _, p in ipairs(vim.fn.glob(pattern, false, true)) do
      local content = utils.read_file(p)
      if content then
        table.insert(chunks, file_block(p, content))
        table.insert(all_paths, p)
      end
    end
  end

  cb(nil, {
    prompt = table.concat(chunks, "\n"),
    meta = { config_files = all_paths },
  })
end

-- opts: (none — reads state.sel_buf, state.sel_start, state.sel_end set by the keymap)
function M.visual_selection(opts, state, cb)
  local buf = state.sel_buf
  local start_line = state.sel_start
  local end_line = state.sel_end

  if not buf or not start_line or not end_line then
    cb("No visual selection captured.")
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
  if #lines == 0 then
    cb("Visual selection is empty.")
    return
  end

  local filename = vim.api.nvim_buf_get_name(buf)
  local header = string.format("SELECTION BEGIN: %s (lines %d-%d)", filename, start_line, end_line)
  local block = header .. "\n" .. table.concat(lines, "\n") .. "\nSELECTION END\n"

  cb(nil, { prompt = block, meta = { sel_file = filename, sel_start = start_line, sel_end = end_line } })
end

-- opts: (none) — reads .ai_context.md into the user turn (for rewrite workflows)
function M.context_file_raw(opts, state, cb)
  local path = utils.find_context_file()
  if not path then
    cb("No .ai_context.md found to rewrite.")
    return
  end
  local content, err = utils.read_file(path)
  if not content then
    cb("Could not read .ai_context.md: " .. (err or "unknown error"))
    return
  end
  cb(nil, {
    prompt = content,
    meta = { context_file_path = path },
  })
end

-- opts: (none)
function M.project_context(opts, state, cb)
  local path = utils.find_context_file()

  if path then
    local content, err = utils.read_file(path)
    if not content then
      cb("Could not read .ai_context.md: " .. (err or "unknown error"))
      return
    end
    cb(nil, {
      meta = { project_context = content, project_context_file = path },
    })
  else
    vim.ui.select(
      { "Create .ai_context.md here", "Skip for now" },
      { prompt = "No .ai_context.md found in project:" },
      function(choice)
        if choice == "Create .ai_context.md here" then
          local new_path = vim.fn.getcwd() .. "/.ai_context.md"
          utils.create_context_file(new_path)
          vim.cmd("split " .. vim.fn.fnameescape(new_path))
          cb("Created .ai_context.md — fill it in and re-run.")
        else
          cb(nil, nil)
        end
      end
    )
  end
end

return M
