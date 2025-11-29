local M = {}

local harpoon_ok, harpoon = pcall(require, "harpoon")

-- Support Harpoon v2 (harpoon2 branch) and fall back to the legacy API if present.
local function get_harpoon2_files()
  if not harpoon_ok or type(harpoon.list) ~= "function" then
    return {}
  end

  local ok, list = pcall(function()
    return harpoon:list()
  end)
  if not ok or not list then
    return {}
  end

  local files = {}

  if type(list.get_length) == "function" and type(list.get) == "function" then
    for idx = 1, list:get_length() do
      local item = list:get(idx)
      local filename = item and (item.value or item.filename or item.file or item)
      if filename and filename ~= "" then
        table.insert(files, { filename = filename })
      end
    end
    return files
  end

  for _, item in ipairs(list.items or {}) do
    local filename = item.value or item.filename or item.file or item
    if filename and filename ~= "" then
      table.insert(files, { filename = filename })
    end
  end
  return files
end

local function get_legacy_files()
  local ok, marked = pcall(require, "harpoon.mark")
  if not ok or type(marked.get_length) ~= "function" then
    return {}
  end

  local files = {}
  for idx = 1, marked.get_length() do
    local filename = marked.get_marked_file_name(idx)
    if filename and filename ~= "" then
      table.insert(files, { filename = filename })
    end
  end
  return files
end

function M.get_marked_files()
  local files = get_harpoon2_files()
  if #files > 0 then
    return files
  end
  return get_legacy_files()
end

return M
