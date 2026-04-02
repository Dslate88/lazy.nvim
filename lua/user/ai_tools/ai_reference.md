# AI Tools Reference

_Source of truth: `lua/plugins/ai-tools.lua`, `lua/user/ai_tools/scripts/registry.lua`, and `lua/plugins/snacks.lua`_

## Keymaps

---

### `<leader>ac` — Chat

| Field                | Value        |
| -------------------- | ------------ |
| **Script**           | `chat`       |
| **Window**           | popup        |
| **Conversational**   | no           |
| **Context gathered** | `user_prompt` |

**What it does:** Prompts the user for a free-form message, then sends it to the AI with a system message that enables markdown-formatted output including code blocks.

**When to invoke:** General questions, quick lookups, or one-off tasks that don't require file context.

---

### `<leader>ar` — Harpoon Goal

| Field                | Value                                             |
| -------------------- | ------------------------------------------------- |
| **Script**           | `harpoon_review`                                  |
| **Window**           | split                                             |
| **Conversational**   | yes                                               |
| **Context gathered** | `project_context`, `user_prompt`, `harpoon_files` |

**What it does:** Prompts for a goal, then sends the harpoon-marked files and project context to an expert code reviewer whose system prompt is focused on that specific goal. Opens in a split for an ongoing conversation.

**When to invoke:** When you want the AI to review or reason about your harpoon-pinned files toward a specific objective.

**In-buffer keymaps** _(conversational)_:

- `<leader>f` — send a follow-up message
- `<leader>e` — capture insights into `.ai_context.md`

---

### `<leader>ad` — Design Patterns

| Field                | Value                                             |
| -------------------- | ------------------------------------------------- |
| **Script**           | `design_patterns`                                 |
| **Window**           | split                                             |
| **Conversational**   | yes                                               |
| **Context gathered** | `project_context`, `user_prompt`, `harpoon_files` |

**What it does:** Optionally prompts for focus areas, then sends harpoon-marked files to a design patterns coach that analyzes pattern opportunities and misuses, explains tradeoffs, and suggests small implementation steps.

**When to invoke:** When refactoring or reviewing architecture and you want pattern-level feedback on harpoon-pinned files.

**In-buffer keymaps** _(conversational)_:

- `<leader>f` — send a follow-up message
- `<leader>e` — capture insights into `.ai_context.md`

---

### `<leader>ag` — Git Diff

| Field                | Value                                        |
| -------------------- | -------------------------------------------- |
| **Script**           | `git_diff_review`                            |
| **Window**           | split                                        |
| **Conversational**   | yes                                          |
| **Context gathered** | `project_context`, `user_prompt`, `git_diff` |

**What it does:** Optionally prompts for a goal (e.g., commit message, review focus), then sends the staged git diff and project context to a git assistant. If no goal is provided, it defaults to summarizing and reviewing the changes.

**When to invoke:** Before committing to review staged changes or draft a commit message.

**In-buffer keymaps** _(conversational)_:

- `<leader>f` — send a follow-up message
- `<leader>e` — capture insights into `.ai_context.md`

---

### `<leader>ao` — Organize Context File

| Field                | Value              |
| -------------------- | ------------------ |
| **Script**           | `rewrite_context`  |
| **Window**           | split              |
| **Conversational**   | no                 |
| **Context gathered** | `context_file_raw` |

**What it does:** Reads the raw `.ai_context.md` file and instructs the AI to rewrite it for signal quality — preserving all specific technical detail while removing genuine redundancy and vague filler. The AI explains its reasoning before presenting the full rewritten file.

**When to invoke:** When `.ai_context.md` has grown verbose, redundant, or contains low-signal content.

---

### `<leader>ai` — Open Context File

_(external module — `scripts.open_context_file()`, not a registry entry)_

**What it does:** Opens `.ai_context.md` in a vertical split. If the file does not exist at or above the current working directory, it creates one from a default template at `CWD/.ai_context.md`.

**When to invoke:** To inspect or manually edit the project context file.

---

### `<leader>ae` — Extract Context

| Field                | Value                               |
| -------------------- | ----------------------------------- |
| **Script**           | `extract_context`                   |
| **Window**           | split                               |
| **Conversational**   | yes                                 |
| **Context gathered** | `project_context`, `harpoon_files`  |

**What it does:** Analyzes harpoon-marked files against the existing project context and outputs only the new markdown content that should be appended — covering architectural decisions, design patterns, conventions, and cross-repo relationships not yet captured.

**When to invoke:** After writing new code or completing a refactor to keep `.ai_context.md` current.

**In-buffer keymaps** _(conversational)_:

- `<leader>f` — send a follow-up message
- `<leader>e` — capture insights into `.ai_context.md`

---

### `<leader>ak` — Keymap Query

| Field                | Value                           |
| -------------------- | ------------------------------- |
| **Script**           | `keymap_query`                  |
| **Window**           | popup                           |
| **Conversational**   | no                              |
| **Context gathered** | `user_prompt`, `config_files`   |

**What it does:** Prompts for a keymap question, then sends it along with the local `keymaps.lua` and all plugin specs (`lua/plugins/*.lua`) to a Neovim/LazyVim expert that answers with exact key combos and descriptions, including relevant LazyVim defaults.

**When to invoke:** When you can't remember a keymap or want to discover what's available.

---

### `<leader>as` — Analyze File

| Field                | Value                         |
| -------------------- | ----------------------------- |
| **Script**           | `analyze_file`                |
| **Window**           | split                         |
| **Conversational**   | yes                           |
| **Context gathered** | `user_prompt`, `active_file`  |

**What it does:** Prompts for a question about the currently active file, then sends the file contents to an expert code analyst that reasons through the question step by step without rewriting code unless explicitly asked.

**When to invoke:** When you want to understand, trace, or reason about the file currently open in the editor.

**In-buffer keymaps** _(conversational)_:

- `<leader>f` — send a follow-up message
- `<leader>e` — capture insights into `.ai_context.md`

---

### `<leader>ah` — Harpoon Add from Picker

_(defined in `lua/plugins/snacks.lua`)_

**What it does:** From an open snacks picker, takes all tab-selected files (falling back to the current item if none are selected) and appends them to the harpoon list.

**When to invoke:** When you want to build or extend a harpoon context set by selecting files in a snacks picker before running an AI workflow.

---

### `<leader>aH` — Harpoon Replace from Picker

_(defined in `lua/plugins/snacks.lua`)_

**What it does:** From an open snacks picker, clears the harpoon list and replaces it with the tab-selected files (falling back to the current item if none are selected).

**When to invoke:** When you want to swap your entire harpoon context to a new set of files selected in a snacks picker.

---

### `<leader>at` — Terraform Docs

_(external module — `user.terraform_docs.lookup()`)_

**What it does:** Looks up Terraform documentation via the `user.terraform_docs` module.

**When to invoke:** When working in a Terraform file and you need provider or resource documentation.

---

### `<leader>ap` — Prompt Gen

_(external module — `user.prompt_gen.execute()`)_

**What it does:** Executes the prompt generation utility from `user.prompt_gen`, which builds a prompt from harpoon-marked files.

**When to invoke:** When you need to generate a structured prompt from your harpoon list for use outside Neovim.

---

### `<leader>aR` — AI Reference

_(external module — `scripts.open_reference()`, not a registry entry)_

**What it does:** Opens `lua/user/ai_tools/ai_reference.md` (this file) in a vertical split.

**When to invoke:** To quickly look up available AI tool keymaps and their behavior.

---

### `<leader>aU` — Usage Summary

_(external module — `user.ai_tools.usage.summary()`)_

**What it does:** Displays a summary of AI tools usage via the `user.ai_tools.usage` module.

**When to invoke:** To review how often each AI workflow has been invoked.

---
