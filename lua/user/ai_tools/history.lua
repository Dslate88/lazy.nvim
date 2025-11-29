local M = {}

local entries = {}

local function ensure(action)
  local key = action or "default"
  entries[key] = entries[key] or {}
  return key, entries[key]
end

---@param action string|nil
---@param prompt string
---@param response string
---@param meta table|nil
function M.add(action, prompt, response, meta)
  local key, list = ensure(action)
  table.insert(list, {
    prompt = prompt,
    response = response,
    meta = meta or {},
    timestamp = os.time(),
  })
  return #list, key
end

function M.get(action, index)
  local _, list = ensure(action)
  return list[index]
end

function M.count(action)
  local _, list = ensure(action)
  return #list
end

function M.list(action)
  local _, list = ensure(action)
  return list
end

return M
