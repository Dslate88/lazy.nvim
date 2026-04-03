# AI Tools Reference

_Source of truth: `lua/plugins/ai-tools.lua` and `lua/user/ai_tools/scripts/registry.lua`_

## Keymaps

---

### `<leader>ac` — Chat

| Field                | Value         |
| -------------------- | ------------- |
| **Script**           | `chat`        |
| **Window**           | popup         |
| **Conversational**   | no            |
| **Context gathered** | `user_prompt` |

**What it does:** Prompts for a free-form message and sends it to a general technical assistant that responds in markdown with properly fenced code blocks.

**When to invoke:** General questions, quick lookups, or one-off tasks that don't require file context.

---

### `<leader>ar` — Harpoon Goal

| Field                | Value                                             |
| -------------------- | ------------------------------------------------- |
| **Script**           | `harpoon_review`                                  |
| **Window**           | split                                             |
| **Conversational**   | yes                                               |
| **Context gathered** | `project_context`, `user_prompt`, `harpoon_files` |

**What it does:** Prompts for a goal, then sends the harpoon-marked files to an expert code reviewer. The reviewer addresses the goal first, identifies bugs and edge cases, and educates the user if a misconception is detected. Project architecture context is injected into the system message when `architecture.md` is present.

**When to invoke:** When you want the AI to review or reason about your harpoon-pinned files toward a specific objective.

**In-buffer keymaps** _(conversational)_:

- `<leader>f` — send a follow-up message

---

### `<leader>ad` — Design Patterns

| Field                | Value                                             |
| -------------------- | ------------------------------------------------- |
| **Script**           | `design_patterns`                                 |
| **Window**           | split                                             |
| **Conversational**   | yes                                               |
| **Context gathered** | `project_context`, `user_prompt`, `harpoon_files` |

**What it does:** Optionally prompts for focus areas, then sends harpoon-marked files to a design coach that analyzes structural and design quality using software engineering principles. For each observation it names the pattern, explains why it applies, proposes the smallest concrete improvement, and notes tradeoffs — adapting to the language idioms of the code.

**When to invoke:** When refactoring or reviewing architecture and you want pattern-level feedback on harpoon-pinned files.

**In-buffer keymaps** _(conversational)_:

- `<leader>f` — send a follow-up message

---

### `<leader>ag` — Git Diff

| Field                | Value                                        |
| -------------------- | -------------------------------------------- |
| **Script**           | `git_diff_review`                            |
| **Window**           | split                                        |
| **Conversational**   | yes                                          |
| **Context gathered** | `project_context`, `user_prompt`, `git_diff` |

**What it does:** Optionally prompts for a review focus, then sends the staged git diff to a senior engineer who reviews for logic errors, unintended side effects, missing edge cases, code quality issues, unrelated changes, and leftover artifacts. Response is structured as: summary → findings by severity → recommendations.

**When to invoke:** Before committing to review staged changes.

**In-buffer keymaps** _(conversational)_:

- `<leader>f` — send a follow-up message

---

### `<leader>ab` — Branch Diff

| Field                | Value                          |
| -------------------- | ------------------------------ |
| **Script**           | `branch_diff_review`           |
| **Window**           | split                          |
| **Conversational**   | yes                            |
| **Context gathered** | `project_context`, `git_diff`  |

**What it does:** Sends the full diff between `origin/main` and the current branch HEAD to a senior engineer who provides: a summary of all changes grouped by theme, what appears complete, what looks incomplete or stubbed, any concerns, and suggested next steps toward merge readiness.

**When to invoke:** When you want a high-level view of everything you've done on a feature branch — useful for a progress check or to identify what remains to do.

**In-buffer keymaps** _(conversational)_:

- `<leader>f` — send a follow-up message

---

### `<leader>ai` — Open architecture.md

_(external module — `scripts.open_arch_file()`, not a registry entry)_

**What it does:** Opens `architecture.md` in a vertical split by searching upward from the current working directory to the git root. Displays a warning if no file is found and suggests running `<leader>aA` to generate one.

**When to invoke:** To inspect or manually edit the project architecture document.

---

### `<leader>ak` — Keymap Query

| Field                | Value                         |
| -------------------- | ----------------------------- |
| **Script**           | `keymap_query`                |
| **Window**           | popup                         |
| **Conversational**   | no                            |
| **Context gathered** | `user_prompt`, `config_files` |

**What it does:** Prompts for a keymap question, then sends it along with `keymaps.lua` and all plugin specs (`lua/plugins/*.lua`) to a Neovim/LazyVim expert that answers with exact key combos and descriptions, including relevant LazyVim defaults not visible in local config.

**When to invoke:** When you can't remember a keymap or want to discover what's available.

---

### `<leader>as` — Analyze File

| Field                | Value                        |
| -------------------- | ---------------------------- |
| **Script**           | `analyze_file`               |
| **Window**           | split                        |
| **Conversational**   | yes                          |
| **Context gathered** | `user_prompt`, `active_file` |

**What it does:** Prompts for a question about the active buffer, then sends the file to an expert engineer who answers the question first, then provides a structured breakdown covering purpose, structure, data flow, dependencies, and notable behaviors.

**When to invoke:** When you want to understand, trace, or reason about the file currently open in the editor.

**In-buffer keymaps** _(conversational)_:

- `<leader>f` — send a follow-up message

---

### `<leader>at` — Terraform Docs

_(external module — `user.terraform_docs.lookup()`)_

**What it does:** Looks up Terraform documentation via the `user.terraform_docs` module.

**When to invoke:** When working in a Terraform file and you need provider or resource documentation.

---

### `<leader>ap` — Prompt Gen

_(external module — `user.prompt_gen.execute()`)_

**What it does:** Builds a structured prompt from harpoon-marked files via the `user.prompt_gen` module.

**When to invoke:** When you need to generate a prompt from your harpoon list for use outside Neovim.

---

### `<leader>aR` — View Keymap Details

_(external module — `scripts.view_keymap_details()`, not a registry entry)_

**What it does:** Opens `lua/user/ai_tools/ai_reference.md` (this file) in a vertical split.

**When to invoke:** To quickly look up available AI tool keymaps and their behavior.

---

### `<leader>aU` — Usage Summary

_(external module — `user.ai_tools.usage.summary()`)_

**What it does:** Displays a summary of AI tools usage via the `user.ai_tools.usage` module.

**When to invoke:** To review how often each AI workflow has been invoked.

---

### `<leader>aA` — Generate architecture.md

_(external module — `user.arch_gen.run()`)_

**What it does:** Generates an `architecture.md` file for the current project via the `user.arch_gen` module.

**When to invoke:** When no `architecture.md` exists yet, or when you want to regenerate it for a project.

---

### `<leader>ah` — Harpoon Add from Picker

_(defined in `lua/plugins/snacks.lua`)_

**What it does:** From an open Snacks picker, takes all tab-selected files (falling back to the current item if none are selected) and appends them to the harpoon list.

**When to invoke:** When you want to build or extend a harpoon context set by selecting files in a Snacks picker before running an AI workflow.

---

### `<leader>aH` — Harpoon Replace from Picker

_(defined in `lua/plugins/snacks.lua`)_

**What it does:** From an open Snacks picker, clears the harpoon list and replaces it with the tab-selected files (falling back to the current item if none are selected).

**When to invoke:** When you want to swap your entire harpoon context to a new set of files selected in a Snacks picker.

---
