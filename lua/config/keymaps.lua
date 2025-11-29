-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
local map = vim.keymap.set

-- ===========================================================
-- General Mappings
-- ===========================================================
-- Swap to the most recent buffer
map("n", "<leader><leader>", "<C-^>", { desc = "Last Buffer" })

-- Move current line up/down
map("n", "<leader>j", ":m+<CR>==", { desc = "Move Line Down" })
map("n", "<leader>k", ":m-2<CR>==", { desc = "Move Line Up" })
map("v", "<leader>j", ":m '>+1<CR>gv=gv", { desc = "Move Selection Down" })
map("v", "<leader>k", ":m '<-2<CR>gv=gv", { desc = "Move Selection Up" })
