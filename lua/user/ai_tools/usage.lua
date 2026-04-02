local M = {}

local data_path = vim.fn.stdpath("data") .. "/ai_tools_usage.jsonl"

function M.record(script_name)
  local line = string.format('{"ts":%d,"script":"%s"}', os.time(), script_name)
  local f = io.open(data_path, "a")
  if not f then
    return
  end
  f:write(line .. "\n")
  f:close()
end

function M.summary()
  local ui = require("user.ai_tools.ui")

  local now = os.time()
  local cutoff_7  = now - (7  * 24 * 60 * 60)
  local cutoff_30 = now - (30 * 24 * 60 * 60)

  local counts_7  = {}
  local counts_30 = {}

  local f = io.open(data_path, "r")
  if f then
    for line in f:lines() do
      local ts_str = line:match('"ts":(%d+)')
      local script = line:match('"script":"([^"]+)"')
      if ts_str and script then
        local ts = tonumber(ts_str)
        if ts >= cutoff_30 then
          counts_30[script] = (counts_30[script] or 0) + 1
        end
        if ts >= cutoff_7 then
          counts_7[script] = (counts_7[script] or 0) + 1
        end
      end
    end
    f:close()
  end

  local function sorted_pairs(counts)
    local rows = {}
    for script, count in pairs(counts) do
      table.insert(rows, { script = script, count = count })
    end
    table.sort(rows, function(a, b) return a.count > b.count end)
    return rows
  end

  local function render_section(title, rows)
    local lines = { "## " .. title, "" }
    if #rows == 0 then
      table.insert(lines, "_No usage recorded._")
    else
      table.insert(lines, "| Script | Count |")
      table.insert(lines, "| ------ | ----- |")
      for _, row in ipairs(rows) do
        table.insert(lines, string.format("| %s | %d |", row.script, row.count))
      end
    end
    return table.concat(lines, "\n")
  end

  local output = table.concat({
    "# AI Tools Usage",
    "",
    render_section("Last 7 Days", sorted_pairs(counts_7)),
    "",
    render_section("Last 30 Days", sorted_pairs(counts_30)),
  }, "\n")

  ui.display_response(output, "popup")
end

return M
