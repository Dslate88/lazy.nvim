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
Produce a concise architecture.md optimized for LLM consumption — this document will be injected as context when an AI reviews code from this project.

HARD LIMIT: Stay under 600 words. Every sentence must earn its place.

Focus on what CANNOT be inferred by reading individual source files: architectural intent, design decisions, cross-cutting conventions, and gotchas.

Use this exact structure:

# Architecture

## Purpose
1-2 sentences: what this system does and its scope.

## Key Decisions
Bullet points. Each: the decision, then why it was made (constraint, tradeoff, or requirement that drove it).

## Module Relationships
How the major components connect and depend on each other. Only describe relationships — do not describe what individual modules do (the LLM can read the code).

## Conventions
Patterns and rules the codebase follows that are not obvious from reading a single file. Include naming conventions, structural patterns, and implicit contracts between modules.

## Anti-patterns / Gotchas
Things that look tempting but are wrong in this codebase, and why. Known footguns, implicit coupling, or constraints a newcomer would miss.

## External Integrations
Only non-obvious external dependencies. Skip standard libraries and common frameworks — only list services, APIs, or tools whose role in the system is not self-evident.

## Cross-repo Dependencies
Any dependencies on code outside this repository — shared libraries, sibling repos, or upstream services this repo calls. Write "None identified." if there are none.

Output ONLY the markdown document. No preamble, no explanation, no code fences around the whole document.
Prefer terse bullet points over prose. If a section has nothing worth noting, write "None." and move on.
]]

local ROLLUP_SYSTEM_PROMPT = [[
You are a senior software architect. You will be given architecture.md documents for several related repositories.
Synthesize them into a single architecture.md optimized for LLM consumption.

HARD LIMIT: Stay under 800 words.

Use this exact structure:

# Architecture (System Overview)

## Purpose
What the overall system does and how the repositories relate.

## Key Decisions
Cross-cutting architectural decisions spanning multiple repos, plus repo-specific decisions worth calling out. Each: the decision, then why.

## Inter-repo Relationships
How repos depend on each other — API calls, shared data stores, shared libraries, deployment order.

## Conventions
Cross-repo patterns, naming rules, and structural norms.

## Anti-patterns / Gotchas
System-wide footguns, implicit coupling between repos, or constraints a newcomer would miss.

Output ONLY the markdown document. No preamble, no explanation, no code fences around the whole document.
Prefer terse bullet points over prose. If a section has nothing worth noting, write "None." and move on.
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

-- Writes the final architecture.md to disk (timestamp + LLM response).
-- cb(err, out_path)
local function write_arch_file(out_path, response, cb)
  local f = io.open(out_path, "w")
  if not f then
    cb("Could not write to " .. out_path, nil)
    return
  end
  f:write(timestamp_header())
  f:write(response)
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
    write_arch_file(repo_path .. "/architecture.md", response, function(write_err, out_path)
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
  for _, arch_path in ipairs(sub_arch_paths) do
    local content = utils.read_file(arch_path)
    if content then
      table.insert(repo_blocks, string.format(
        '<repo path="%s">\n<content>\n%s\n</content>\n</repo>',
        arch_path, content
      ))
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
    write_arch_file(root .. "/architecture.md", response, function(write_err, out_path)
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
