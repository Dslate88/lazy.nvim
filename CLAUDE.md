# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Neovim configuration built on [LazyVim](https://www.lazyvim.org/) with a custom AI assistant framework as its primary extension. LazyVim provides sensible defaults; this config layers custom plugins, keymaps, and a full AI workflow system on top.

## Architecture

```
init.lua                  # Entry point — only loads lua/config/lazy.lua
lua/
  config/
    lazy.lua              # lazy.nvim bootstrap and plugin spec setup
    keymaps.lua           # Custom keybindings (beyond LazyVim defaults)
    options.lua           # Editor options (mostly inherits LazyVim defaults)
    autocmds.lua          # Autocommands (mostly inherits LazyVim defaults)
  plugins/                # lazy.nvim plugin specs (each file = one plugin or group)
  user/
    ai_tools/             # Custom AI assistant framework (see below)
    arch_gen.lua          # Generates architecture.md via LLM from git ls-files
    prompt_gen.lua        # Prompt generation utility
    terraform_docs.lua    # Terraform registry docs lookup (`<leader>at`)
lazyvim.json              # LazyVim extras (languages/tools enabled)
.neoconf.json             # LSP/neodev library configuration
```

### LazyVim Extras (lazyvim.json)

Enabled extras: `harpoon2`, `docker`, `json`, `markdown`, `python`, `terraform`, `toml`, `yaml`, `dot`.

### Custom AI Tools System (`lua/user/ai_tools/`)

This is the most complex part of the config — a full AI assistant framework:

| File/Dir               | Role                                                                                                                                        |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `config.lua`           | Defaults: provider (`openai`), model, timeout, debug flag                                                                                   |
| `providers/`           | Pluggable AI backends: `openai.lua`, `azure.lua`, `provider_factory.lua`                                                                    |
| `context/builders.lua` | Async context collectors: `user_prompt`, `harpoon_files`, `git_diff`, `git_log`, `config_files`, `active_file`, `project_context`              |
| `scripts/registry.lua` | Workflow definitions (chat, harpoon_review, git_diff_review, commit_message, branch_diff_review, design_patterns, keymap_query, analyze_file); also the `run()` entry point. Workflows with `conversational = true` (harpoon_review, git_diff_review, branch_diff_review, design_patterns, analyze_file) bind `<leader>f` for follow-ups. |
| `scripts/init.lua`     | Public API shim — thin wrappers that call `registry.run(action)`                                                                            |
| `runner.lua`           | Executes requests via selected provider                                                                                                     |
| `ui.lua`               | Popup/split windows for input and responses; binds `<leader>f` follow-up in response buffers                                                |
| `usage.lua`            | Tracks per-action invocation counts; `<leader>aU` shows a summary                                                                          |
| `logger.lua`           | Debug logging to `$NVIM_DATA/ai_tools.log`                                                                                                  |
| `harpoon.lua`          | Harpoon integration for getting marked file list                                                                                            |
| `utils.lua`            | Shared helpers: `find_arch_file()` (walks up to git root looking for `architecture.md`), `read_file()`, etc.                                |
| `init.lua`             | Module entry point — re-exports everything                                                                                                  |

**Request flow:** keymap → script (from registry) → context builders (async, sequential) → runner → provider → UI window.

**Project context:** `architecture.md` (searched upward from CWD to git root via `utils.find_arch_file()`) is automatically injected into the system message for workflows that include the `project_context` builder (`harpoon_review`, `git_diff_review`, `design_patterns`). Generate or regenerate it with `<leader>aA`.

**Environment variables required:**

- `OPENAI_API_KEY`
- `AZURE_OPENAI_API_KEY` and `AZURE_OPENAI_ENDPOINT` (if using Azure)

### `arch_gen.lua` — Architecture Document Generator

`<leader>aA` runs `arch_gen.run()`, which:
1. Detects whether CWD contains a single git repo or multiple sub-repos (monorepo).
2. Runs `git ls-files` to collect tracked files, filtering by extension allowlist and 100 KB size limit.
3. Shows a confirmation prompt with file/token counts before calling the LLM.
4. For **single-repo**: generates `{repo_root}/architecture.md` and opens it in a vsplit.
5. For **multi-repo**: generates per-repo `architecture.md` files, then synthesizes a rollup `architecture.md` at the root.

## Key Keymaps

### AI Tools (`<leader>a`)

| Keymap       | Action                                                            |
| ------------ | ----------------------------------------------------------------- |
| `<leader>ac` | AI chat (popup)                                                   |
| `<leader>ar` | Review harpoon-marked files with AI                               |
| `<leader>ad` | Design pattern analysis of harpoon-marked files                   |
| `<leader>ag` | Review staged git diff with AI                                    |
| `<leader>aG` | Generate a conventional commit message from staged diff           |
| `<leader>ab` | Review full branch diff (origin/main...HEAD) with AI              |
| `<leader>as` | Analyze current file with AI                                      |
| `<leader>ak` | Ask AI about available keymaps                                    |
| `<leader>aR` | View keymap details (opens `ai_reference.md`)                     |
| `<leader>ai` | Open `architecture.md` in a vsplit                                |
| `<leader>aA` | Generate `architecture.md` via LLM from git-tracked files         |
| `<leader>at` | Terraform docs lookup                                             |
| `<leader>ap` | Generate prompt from harpoon files                                |
| `<leader>aU` | Show AI tool usage summary                                        |

### In-response keymaps (conversational workflows)

Workflows marked `conversational = true` in the registry bind these inside their response buffer:

| Keymap       | Action                                      |
| ------------ | ------------------------------------------- |
| `<leader>f`  | Send a follow-up message (continues the conversation) |

### Harpoon (`<leader>h`)

| Keymap                      | Action                       |
| --------------------------- | ---------------------------- |
| `<leader>ha`                | Add file to harpoon          |
| `<leader>hu`                | Toggle harpoon menu          |
| `<leader>hn` / `<leader>hp` | Next / previous harpoon file |

### Other custom

| Keymap                    | Action                      |
| ------------------------- | --------------------------- |
| `<leader><leader>`        | Switch to last buffer       |
| `<leader>j` / `<leader>k` | Move line/selection down/up |

## Conventions

- Plugin specs live in `lua/plugins/` — one file per plugin or logical group.
- Custom code that is not a plugin goes in `lua/user/`.
- Each directory uses `init.lua` to export its submodules.
- Module tables are named `M` by convention.
- New AI workflows are added to `scripts/registry.lua`; new providers to `providers/`.
- Context builders in `context/builders.lua` follow the signature `function(opts, state, cb)` where `cb(err, {prompt?, meta?})`.

## Open TODOs (from comments in code)

- `which-key.lua`: convert icon sets to Nerd Font, improve group icons
- `snacks.lua`: build quickfix-based AI tools script (similar to harpoon_list)
