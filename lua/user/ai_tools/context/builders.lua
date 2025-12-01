local utils = require("user.ai_tools.utils")
local ui = require("user.ai_tools.ui")
local marked = require("user.ai_tools.harpoon")

local M = {}

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
    table.insert(chunks, "FILE NAME BEGIN: " .. file.filename .. "\n")
    table.insert(chunks, "FILE CONTENT BEGIN:\n" .. content .. "\nFILE CONTENT END\n")
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

return M
