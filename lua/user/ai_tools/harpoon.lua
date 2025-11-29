local M = {}

local harpoon = require("harpoon")

-- Harpoon v2 helper: returns marked files using the new list API.
function M.get_marked_files()
  local ok, list = pcall(function()
    return harpoon:list()
  end)
  if not ok or not list or type(list.length) ~= "function" or type(list.get) ~= "function" then
    return {}
  end

  local files = {}

  for idx = 1, list:length() do
    local item = list:get(idx)
    if item ~= nil then
      local filename = item.value or item.filename or item.file or item
      if filename and filename ~= "" then
        table.insert(files, { filename = filename })
      end
    end
  end

  return files
end

return M
