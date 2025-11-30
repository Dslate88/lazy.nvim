local utils = require("user.ai_tools.utils")
local ui = require("user.ai_tools.ui")
local marked = require("user.ai_tools.harpoon")

local M = {}

-- opts: prompt (string), allow_empty (bool), save_as (string), enable_history (bool), history_action (string)
function M.user_prompt(opts, state, cb)
  local label = opts.prompt or "Enter input:"
  ui.get_user_prompt({
    prompt = label,
    enable_history = opts.enable_history,
    action = opts.history_action or "default",
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

-- opts: max_bytes (number|nil)
function M.harpoon_files(opts, state, cb)
  local files = marked.get_marked_files()
  if #files == 0 then
    cb("No marked files found during execution.")
    return
  end

  local chunks = {}
  local meta = { files = files, truncated = {} }

  for _, file in ipairs(files) do
    local content, err = utils.read_file(file.filename)
    if not content then
      cb("Error reading file: " .. (err or "unknown error"))
      return
    end
    if opts.max_bytes and #content > opts.max_bytes then
      content = content:sub(1, opts.max_bytes) .. "\n\n[Truncated due to size]"
      table.insert(meta.truncated, file.filename)
    end
    table.insert(chunks, "FILE NAME BEGIN: " .. file.filename .. "\n")
    table.insert(chunks, "FILE CONTENT BEGIN:\n" .. content .. "\nFILE CONTENT END\n")
  end

  cb(nil, {
    prompt = table.concat(chunks, "\n"),
    meta = meta,
  })
end

-- opts: max_bytes (number|nil), include_unstaged (bool), git_cmd (table|nil), cwd (string|nil)
function M.git_diff(opts, state, cb)
  local max_bytes = opts.max_bytes or 200 * 1024
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

    local truncated = false
    local prompt = stdout
    if max_bytes and #prompt > max_bytes then
      prompt = prompt:sub(1, max_bytes) .. "\n\n[Diff truncated to " .. max_bytes .. " bytes]"
      truncated = true
    end

    cb(nil, {
      prompt = table.concat({
        "GIT DIFF BEGIN",
        prompt,
        "GIT DIFF END",
      }, "\n"),
      meta = {
        git_cmd = cmd,
        include_unstaged = include_unstaged,
        truncated = truncated,
        bytes = #stdout,
        max_bytes = max_bytes,
      },
    })
  end)
end

return M
