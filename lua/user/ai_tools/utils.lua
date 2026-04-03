local M = {}

-- Walks up from start_dir looking for architecture.md, stopping at the git root.
-- arch_gen always writes to {repo_root}/architecture.md, so there is no reason to go higher.
function M.find_arch_file(start_dir)
  local dir = start_dir or vim.fn.getcwd()
  while true do
    local candidate = dir .. "/architecture.md"
    if vim.fn.filereadable(candidate) == 1 then
      return candidate
    end
    if vim.fn.isdirectory(dir .. "/.git") == 1 then
      return nil
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      return nil
    end
    dir = parent
  end
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

return M
