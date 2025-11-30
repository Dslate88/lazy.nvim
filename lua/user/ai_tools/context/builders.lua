local utils = require("user.ai_tools.utils")
local ui = require("user.ai_tools.ui")
local marked = require("user.ai_tools.harpoon")

local M = {}

-- Generic user prompt builder (async).
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

-- Gather contents of harpoon-marked files.
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

return M
