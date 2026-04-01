local M = {}

M.context_file_template = table.concat({
  "# Project Context",
  "",
  "## Architecture",
  "",
  "## Key Decisions",
  "",
  "## Cross-repo Relationships",
  "",
  "## Conventions",
  "",
  "## Current Focus",
  "",
}, "\n")

function M.find_context_file(start_dir)
  local dir = start_dir or vim.fn.getcwd()
  while true do
    local candidate = dir .. "/.ai_context.md"
    if vim.fn.filereadable(candidate) == 1 then
      return candidate
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      return nil
    end
    dir = parent
  end
end

function M.find_or_default_context_path()
  return M.find_context_file() or (vim.fn.getcwd() .. "/.ai_context.md")
end

function M.create_context_file(path)
  local f = io.open(path, "w")
  if f then
    f:write(M.context_file_template)
    f:close()
  end
end

function M.append_to_file(path, content)
  local f = io.open(path, "a")
  if not f then
    return nil, "Could not open file for appending: " .. path
  end
  f:write("\n" .. content)
  f:close()
  return true
end

function M.normalize_path(path)
  return path:gsub("\\", "/")
end

function M.copy_to_clipboard(text)
  vim.fn.setreg("+", text)
  print("Prompt copied to clipboard!")
end

function M.read_file(file_path)
  local normalized_path = M.normalize_path(file_path)

  local file = io.open(normalized_path, "r")
  if not file then
    return nil, "Could not open file: " .. normalized_path
  end

  local content = file:read("*all")
  file:close()

  return content
end

-- NOT USING
function M.chunk_text(text, chunk_size)
  if not text then
    return {}
  end

  local size = chunk_size or math.max(#text, 1)
  local chunks = {}
  local i = 1

  while i <= #text do
    table.insert(chunks, string.sub(text, i, i + size - 1))
    i = i + size
  end

  return chunks
end

return M
