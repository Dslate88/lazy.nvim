local M = {}

local DEFAULT_AWS_VERSION = "6.38.0"
local LOCK_FILE_NAME = ".terraform.lock.hcl"
local BASE_URL =
  "https://raw.githubusercontent.com/hashicorp/terraform-provider-aws/v%s/website/docs/%s/%s.html.markdown"

local function find_lock_file(start_dir)
  local dir = start_dir or vim.fn.getcwd()
  while true do
    local candidate = dir .. "/" .. LOCK_FILE_NAME
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

local function parse_aws_version(lock_path)
  local content = require("user.ai_tools.utils").read_file(lock_path)
  if not content then
    return nil
  end

  local in_aws_block = false
  for line in content:gmatch("[^\n]+") do
    if not in_aws_block then
      if line:match('provider%s+"[^"]*hashicorp/aws"') then
        in_aws_block = true
      end
    else
      local ver = line:match('%s*version%s*=%s*"([%d%.]+)"')
      if ver then
        return ver
      end
      if line:match("^%s*}") then
        return nil
      end
    end
  end

  return nil
end

local function detect_block_type()
  local ok, node = pcall(vim.treesitter.get_node)
  if not ok or not node then
    return nil
  end

  local current = node
  while current do
    if current:type() == "block" then
      local keyword_node = current:child(0)
      if keyword_node and keyword_node:type() == "identifier" then
        local keyword = vim.treesitter.get_node_text(keyword_node, 0)
        if keyword == "resource" then
          return "r"
        elseif keyword == "data" then
          return "d"
        end
      end
    end
    current = current:parent()
  end

  return nil
end

local function strip_frontmatter(text)
  return text:match("^%-%-%-\r?\n.-\n%-%-%-\r?\n(.+)$") or text
end

local function fetch_and_display(url, fallback_url, label)
  vim.system({ "curl", "--silent", "--fail", "--location", "--max-time", "10", url }, { text = true }, function(obj)
    vim.schedule(function()
      if obj.code == 0 and obj.stdout and obj.stdout ~= "" then
        local content = strip_frontmatter(obj.stdout)
        require("user.ai_tools.ui").display_response(content, "split")
      elseif fallback_url then
        fetch_and_display(fallback_url, nil, label)
      else
        vim.notify("Terraform docs not found: " .. label, vim.log.levels.WARN)
      end
    end)
  end)
end

function M.lookup()
  local word = vim.fn.expand("<cword>")

  if not word:match("^aws_") then
    vim.notify("Not an AWS resource (expected 'aws_' prefix): " .. word, vim.log.levels.WARN)
    return
  end

  local slug = word:sub(5)
  local block_type = detect_block_type()

  local version = DEFAULT_AWS_VERSION
  local lock_path = find_lock_file()
  if lock_path then
    version = parse_aws_version(lock_path) or version
  end

  local primary_type = block_type or "r"
  local primary_url = BASE_URL:format(version, primary_type, slug)

  local fallback = nil
  if block_type == nil then
    local secondary_type = (primary_type == "r") and "d" or "r"
    fallback = BASE_URL:format(version, secondary_type, slug)
  end

  vim.notify("Fetching Terraform docs for " .. word .. " (" .. version .. ")...", vim.log.levels.INFO)
  fetch_and_display(primary_url, fallback, word)
end

return M
