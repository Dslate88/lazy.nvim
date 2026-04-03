local utils = require("user.ai_tools.utils")
local provider_factory = require("user.ai_tools.providers.provider_factory")
local config = require("user.ai_tools.config")

local M = {}

-- ─── File filtering constants ─────────────────────────────────────────────────

-- Files whose name ends with any of these suffixes are always skipped,
-- regardless of their final extension (e.g. .terraform.lock.hcl, uv.lock).
local LOCK_SUFFIXES = {
  ".lock",
  ".lock.hcl",
  "package-lock.json",
  "packages.lock.json",
}

-- Allowed file extensions (without leading dot). Files with an extension NOT
-- in this table are skipped. Add entries here as needed.
local ALLOWED_EXTENSIONS = {
  -- General-purpose languages
  py = true, js = true, ts = true, jsx = true, tsx = true,
  go = true, rs = true, java = true, kt = true, scala = true,
  c = true, cpp = true, h = true, hpp = true, cc = true,
  rb = true, php = true, swift = true, cs = true, fs = true,
  lua = true, r = true, jl = true,
  ex = true, exs = true,
  clj = true, cljs = true,
  hs = true, ml = true, mli = true,
  -- Shell / scripting
  sh = true, bash = true, zsh = true, fish = true, ps1 = true,
  -- Query / schema languages
  sql = true, graphql = true, gql = true, proto = true,
  -- IaC / config
  tf = true, hcl = true,
  yml = true, yaml = true,
  toml = true, ini = true, cfg = true, conf = true,
  -- Docs
  md = true, mdx = true, txt = true, rst = true, adoc = true,
  -- Web
  html = true, css = true, scss = true, sass = true, less = true,
  -- Structured data (small config-style files)
  json = true, xml = true,
}

-- Extensionless filenames that should always be included.
local ALLOWED_EXTENSIONLESS = {
  Makefile = true, makefile = true,
  Dockerfile = true, dockerfile = true,
  Jenkinsfile = true, Procfile = true,
  Gemfile = true, Rakefile = true,
  Vagrantfile = true,
}

-- Files larger than this are skipped even if their extension is allowed.
-- Guards against minified JS, generated protobuf descriptors, etc.
local MAX_FILE_BYTES = 100 * 1024  -- 100 KB

-- Rough token estimate: ~4 bytes per token (conservative for mixed code/prose)
local BYTES_PER_TOKEN = 4

-- ─── System prompts ──────────────────────────────────────────────────────────

local ARCH_SYSTEM_PROMPT = [[
You are a senior software architect. You will be given the source files of a codebase.
Analyze them and produce a single architecture.md document with EXACTLY these sections in order:

# Architecture

## 1. Overview
Brief description of what this system does and its scope.

## 2. System Diagram
A Mermaid flowchart showing the major components and their relationships.
Mermaid syntax rules you MUST follow to avoid parse errors:
- Node IDs must be simple alphanumeric (no spaces, no parens): use `A`, `ecr`, `taskDef`, etc.
- If a label needs spaces or parentheses, separate ID from label: `ecr["ECR Repository (pre-existing)"]`
- Subgraph titles with spaces or special characters MUST use the id+label form: `subgraph consumerRepo["Consumer Repo (Terraform)"]`
- Use `<br/>` for line breaks inside labels, never `\n`
- Draw edges between node IDs only, never between subgraph titles
- Example of correct syntax: `subgraph aws["AWS Resources"]` then `ecs["ECS Service"] --> alb["Load Balancer"]`

## 3. Key Components
A table or bulleted list of the main modules/services/packages with a one-line description of each.

## 4. Data Flow
How data moves through the system. Use a Mermaid sequence diagram if the flow is request/response; otherwise prose is fine.

## 5. Key Design Decisions
Inline ADRs or bullet points covering the notable architectural choices and their rationale.

## 6. External Dependencies
Libraries, services, and APIs the system depends on (name + purpose).

## 7. Cross-repo Dependencies
Any dependencies on code outside this repository. Write "None identified." if there are none.

Output ONLY the markdown document. No preamble, no explanation, no code fences around the whole document.
]]

local ROLLUP_SYSTEM_PROMPT = [[
You are a senior software architect. You will be given the architecture.md documents for several related repositories.
Synthesize them into a single unified architecture.md covering the entire system, with EXACTLY these sections in order:

# Architecture (System Overview)

## 1. Overview
What the overall system does and how the repositories relate to each other.

## 2. System Diagram
A Mermaid flowchart showing all repos as top-level nodes plus their key internal components and inter-repo relationships.
Apply the same Mermaid syntax rules: node IDs must be simple alphanumeric, labels with spaces/parens use `id["Label (text)"]`, subgraphs use `subgraph id["Title"]`, line breaks use `<br/>` not `\n`, edges reference node IDs only.

## 3. Key Components
A table or bulleted list covering the major components across all repos, labelled by repo.

## 4. Data Flow
How data flows between and within the repos. Use a Mermaid sequence diagram if appropriate.

## 5. Key Design Decisions
Cross-cutting architectural decisions that span multiple repos, plus repo-specific decisions worth calling out.

## 6. External Dependencies
All external libraries, services, and APIs across all repos (name + purpose + which repo uses it).

## 7. Cross-repo Dependencies
Explicit description of which repos depend on which, and how (API calls, shared libraries, shared data stores, etc.).

Output ONLY the markdown document. No preamble, no explanation, no code fences around the whole document.
]]

-- ─── File filtering ───────────────────────────────────────────────────────────

local function basename(path)
  return path:match("[^/]+$") or path
end

local function is_lock_file(path)
  local name = basename(path)
  for _, suffix in ipairs(LOCK_SUFFIXES) do
    if name:sub(-#suffix) == suffix then
      return true
    end
  end
  return false
end

-- Returns { included = {{path, bytes, tokens}, ...}, skipped_count, estimated_tokens }
local function filter_file_list(abs_paths)
  local included = {}
  local skipped = 0
  local total_bytes = 0

  for _, path in ipairs(abs_paths) do
    -- 1. Lock file check (before extension — catches .terraform.lock.hcl, uv.lock, etc.)
    if is_lock_file(path) then
      skipped = skipped + 1
      goto continue
    end

    local name = basename(path)
    local ext = name:match("%.([^%.]+)$")
    if ext then
      if not ALLOWED_EXTENSIONS[ext:lower()] then
        skipped = skipped + 1
        goto continue
      end
    else
      if not ALLOWED_EXTENSIONLESS[name] then
        skipped = skipped + 1
        goto continue
      end
    end

    do
      local size = vim.fn.getfsize(path)
      if size < 0 or size > MAX_FILE_BYTES then
        skipped = skipped + 1
        goto continue
      end
      total_bytes = total_bytes + size
      table.insert(included, {
        path = path,
        bytes = size,
        tokens = math.ceil(size / BYTES_PER_TOKEN),
      })
    end

    ::continue::
  end

  return {
    included = included,
    skipped_count = skipped,
    estimated_tokens = math.ceil(total_bytes / BYTES_PER_TOKEN),
  }
end

-- ─── Repo detection ───────────────────────────────────────────────────────────

local function detect_repos(root)
  local sub_repos = {}
  local entries = vim.fn.glob(root .. "/*", false, true)
  for _, entry in ipairs(entries) do
    if vim.fn.isdirectory(entry) == 1 and vim.fn.isdirectory(entry .. "/.git") == 1 then
      table.insert(sub_repos, entry)
    end
  end

  if #sub_repos > 0 then
    return { mode = "multi", root = root, sub_repos = sub_repos }
  elseif vim.fn.isdirectory(root .. "/.git") == 1 then
    return { mode = "single", root = root }
  else
    return { mode = "none" }
  end
end

-- ─── File list collection ─────────────────────────────────────────────────────

local function get_file_list(repo_path, cb)
  vim.system({ "git", "ls-files" }, { cwd = repo_path, text = true }, function(obj)
    if obj.code ~= 0 then
      local stderr = (obj.stderr or ""):gsub("%s+$", "")
      cb("git ls-files failed in " .. repo_path .. ": " .. stderr, nil)
      return
    end
    local rel_paths = vim.split(obj.stdout or "", "\n", { trimempty = true })
    local abs_paths = vim.tbl_map(function(p) return repo_path .. "/" .. p end, rel_paths)
    cb(nil, abs_paths)
  end)
end

local function collect_file_lists(repo_paths, cb)
  local results = {}
  local errors = {}
  local completed = 0
  local total = #repo_paths

  for _, repo in ipairs(repo_paths) do
    get_file_list(repo, function(err, paths)
      completed = completed + 1
      if err then
        table.insert(errors, err)
      else
        results[repo] = paths
      end
      if completed == total then
        if #errors > 0 and vim.tbl_isempty(results) then
          cb(table.concat(errors, "; "), nil)
        else
          cb(nil, results)
        end
      end
    end)
  end
end

-- ─── Confirmation ─────────────────────────────────────────────────────────────

-- repo_summaries: { { repo, count, skipped, estimated_tokens }, ... }
local function show_confirmation(repo_summaries, cb)
  local total_files = 0
  local total_tokens = 0
  local lines = { string.format("Generate architecture.md — %d repo(s)\n", #repo_summaries) }

  for _, s in ipairs(repo_summaries) do
    total_files = total_files + s.count
    total_tokens = total_tokens + s.estimated_tokens
    local skip_note = s.skipped > 0 and string.format(", %d skipped", s.skipped) or ""
    table.insert(lines, string.format(
      "  %-36s %2d files%s  (~%d tok)",
      vim.fn.fnamemodify(s.repo, ":t") .. ":",
      s.count,
      skip_note,
      s.estimated_tokens
    ))
  end

  table.insert(lines, string.format("\nTotal: %d files, ~%d tokens estimated", total_files, total_tokens))

  local choice = vim.fn.confirm(table.concat(lines, "\n"), "&Yes\n&No", 2)
  cb(choice == 1)
end

-- ─── XML file block builder ───────────────────────────────────────────────────

-- file_entries: { {path, bytes, tokens}, ... }
local function build_files_xml(file_entries)
  local blocks = {}
  local idx = 0
  for _, entry in ipairs(file_entries) do
    local content = utils.read_file(entry.path)
    if content then
      idx = idx + 1
      table.insert(blocks, string.format(
        '<file index="%d">\n<source>%s</source>\n<file_content>\n%s\n</file_content>\n</file>',
        idx, entry.path, content
      ))
    end
  end
  return string.format("<files>\n%s\n</files>", table.concat(blocks, "\n"))
end

-- ─── Output helpers ──────────────────────────────────────────────────────────

local function timestamp_header()
  return string.format("<!-- arch_gen: %s -->\n", os.date("%Y-%m-%d %H:%M %Z"))
end

-- file_entries: { {path, tokens}, ... }  (tokens optional for rollup inputs)
local function source_files_footer(file_entries, repo_root)
  local lines = { "\n---\n\n## Source Files\n" }
  for _, entry in ipairs(file_entries) do
    local display = repo_root and entry.path:gsub("^" .. vim.pesc(repo_root) .. "/", "") or entry.path
    local tok_note = entry.tokens and string.format(" — ~%d tok", entry.tokens) or ""
    table.insert(lines, string.format("- `%s`%s", display, tok_note))
  end
  return table.concat(lines, "\n")
end

-- Writes the final architecture.md to disk (timestamp + LLM response + source footer).
-- cb(err, out_path)
local function write_arch_file(out_path, response, file_entries, repo_root, cb)
  local f = io.open(out_path, "w")
  if not f then
    cb("Could not write to " .. out_path, nil)
    return
  end
  f:write(timestamp_header())
  f:write(response)
  f:write(source_files_footer(file_entries, repo_root))
  f:write("\n")
  f:close()
  vim.notify("[arch_gen] Done: " .. vim.fn.fnamemodify(out_path, ":~:."))
  cb(nil, out_path)
end

-- ─── LLM call ────────────────────────────────────────────────────────────────

local function call_llm(system_msg, user_msg, cb)
  local cfg = config.get_config()
  local provider_name = cfg.default_provider
  local ok, provider = pcall(provider_factory.get_provider, provider_name)
  if not ok then
    cb("Failed to load provider: " .. tostring(provider), nil)
    return
  end

  local provider_cfg = cfg.providers[provider_name]
  local messages = {
    { role = "system", content = system_msg },
    { role = "user",   content = user_msg },
  }
  local settings = vim.tbl_deep_extend("force", {}, provider_cfg, {
    messages = messages,
    timeout = cfg.timeout,
  })

  provider.send_request(
    user_msg,
    settings,
    vim.schedule_wrap(function(result, err)
      if err then
        cb(err, nil)
        return
      end
      local choice = result and result.choices and result.choices[1]
      local response = choice and choice.message and choice.message.content
      if not response or response == "" then
        cb("Empty response from provider", nil)
        return
      end
      cb(nil, response)
    end)
  )
end

-- ─── Per-repo architecture generation ────────────────────────────────────────

-- file_entries: { {path, bytes, tokens}, ... }
local function generate_arch_for_repo(repo_path, file_entries, cb)
  vim.notify("[arch_gen] Generating architecture for: " .. vim.fn.fnamemodify(repo_path, ":~:."))
  local files_xml = build_files_xml(file_entries)
  call_llm(ARCH_SYSTEM_PROMPT, files_xml, function(err, response)
    if err then
      vim.notify("[arch_gen] Error for " .. repo_path .. ": " .. err, vim.log.levels.ERROR)
      cb(err, nil)
      return
    end
    write_arch_file(repo_path .. "/architecture.md", response, file_entries, repo_path, function(write_err, out_path)
      if write_err then
        vim.notify("[arch_gen] " .. write_err, vim.log.levels.ERROR)
        cb(write_err, nil)
        return
      end
      cb(nil, out_path)
    end)
  end)
end

-- ─── Rollup generation ────────────────────────────────────────────────────────

local function generate_rollup(root, sub_arch_paths, cb)
  local repo_blocks = {}
  local input_entries = {}
  for _, arch_path in ipairs(sub_arch_paths) do
    local content = utils.read_file(arch_path)
    if content then
      table.insert(repo_blocks, string.format(
        '<repo path="%s">\n<content>\n%s\n</content>\n</repo>',
        arch_path, content
      ))
      local size = vim.fn.getfsize(arch_path)
      table.insert(input_entries, {
        path = arch_path,
        tokens = size > 0 and math.ceil(size / BYTES_PER_TOKEN) or nil,
      })
    end
  end
  local combined = table.concat(repo_blocks, "\n\n")
  vim.notify("[arch_gen] Generating rollup architecture.md for: " .. vim.fn.fnamemodify(root, ":~:."))
  call_llm(ROLLUP_SYSTEM_PROMPT, combined, function(err, response)
    if err then
      vim.notify("[arch_gen] Rollup error: " .. err, vim.log.levels.ERROR)
      if cb then cb(err, nil) end
      return
    end
    write_arch_file(root .. "/architecture.md", response, input_entries, root, function(write_err, out_path)
      if write_err then
        vim.notify("[arch_gen] " .. write_err, vim.log.levels.ERROR)
        if cb then cb(write_err, nil) end
        return
      end
      vim.cmd("vsplit " .. vim.fn.fnameescape(out_path))
      if cb then cb(nil, out_path) end
    end)
  end)
end

-- ─── Entry point ──────────────────────────────────────────────────────────────

function M.run()
  local root = vim.fn.expand("%:p:h")
  local detection = detect_repos(root)

  if detection.mode == "none" then
    vim.notify("[arch_gen] No git repo found at " .. root, vim.log.levels.WARN)
    return
  end

  local repo_list = detection.mode == "single" and { root } or detection.sub_repos

  collect_file_lists(repo_list, vim.schedule_wrap(function(err, file_lists)
    if err then
      vim.notify("[arch_gen] " .. err, vim.log.levels.ERROR)
      return
    end

    local filtered_lists = {}
    local repo_summaries = {}
    for _, repo in ipairs(repo_list) do
      local result = filter_file_list(file_lists[repo] or {})
      filtered_lists[repo] = result.included
      table.insert(repo_summaries, {
        repo = repo,
        count = #result.included,
        skipped = result.skipped_count,
        estimated_tokens = result.estimated_tokens,
      })
    end

    show_confirmation(repo_summaries, function(confirmed)
      if not confirmed then
        vim.notify("[arch_gen] Cancelled.")
        return
      end

      local completed = 0
      local total = #repo_list
      local arch_paths = {}

      for _, repo in ipairs(repo_list) do
        generate_arch_for_repo(repo, filtered_lists[repo], function(gen_err, arch_path)
          completed = completed + 1
          if not gen_err then
            table.insert(arch_paths, arch_path)
          end
          if completed == total then
            if detection.mode == "multi" and #arch_paths > 1 then
              generate_rollup(root, arch_paths, nil)
            elseif detection.mode == "single" and #arch_paths == 1 then
              vim.cmd("vsplit " .. vim.fn.fnameescape(arch_paths[1]))
            end
          end
        end)
      end
    end)
  end))
end

return M
