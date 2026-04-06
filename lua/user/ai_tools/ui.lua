local M = {}
local callbacks = {}
local prompt_history = {}
local HISTORY_MAX = 50

local function create_buffer()
  return vim.api.nvim_create_buf(false, true)
end

local function open_window(buf, opts)
  return vim.api.nvim_open_win(buf, true, opts)
end

local function set_buffer_options(buf, options)
  for key, value in pairs(options) do
    vim.api.nvim_buf_set_option(buf, key, value)
  end
end

local RESPONSE_BUF_OPTS = {
  filetype = "markdown",
  wrap = true,
  linebreak = true,
  breakindent = true,
  breakindentopt = "shift:2,min:20",
  textwidth = 0,
  number = false,
  relativenumber = false,
  spell = false,
  conceallevel = 0,
}

local function open_response_window(buf, window_type)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)

  if window_type == "popup" then
    local opts = {
      relative = "editor",
      width = width,
      height = height,
      col = math.floor((vim.o.columns - width) / 2) - 1,
      row = math.floor((vim.o.lines - height) / 2) - 1,
      style = "minimal",
      border = "rounded",
    }
    open_window(buf, opts)
  elseif window_type == "split" then
    vim.cmd("vsplit")
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
  else
    error("Invalid window type: " .. window_type)
  end

  set_buffer_options(buf, RESPONSE_BUF_OPTS)
end

---Display a response in a new buffer/window.
---@param response string
---@param window_type string
---@return number  the response buffer handle
function M.display_response(response, window_type)
  local buf = create_buffer()
  local lines = vim.split(response or "", "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  open_response_window(buf, window_type)

  local map_opts = { buffer = buf, noremap = true, silent = true }
  local function close_buf()
    vim.api.nvim_buf_delete(buf, { force = true })
  end
  vim.keymap.set("n", "q", close_buf, map_opts)
  vim.keymap.set("n", "<Esc>", close_buf, map_opts)
  vim.keymap.set("n", "y", function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    vim.fn.setreg("+", table.concat(lines, "\n"))
    vim.notify("[ai_tools] Response copied to clipboard.")
  end, map_opts)

  return buf
end

---Prompt the user for input, with optional per-action history navigation via j/k.
---@param opts table { prompt?, instructions?, action_id? }
---@param on_submit fun(input:string)
function M.get_user_prompt(opts, on_submit)
  local prompt = opts.prompt or opts.instructions or "Enter input:"
  local action_id = opts.action_id

  local history = (action_id and prompt_history[action_id]) or {}
  local hist_idx = #history + 1 -- points past end = new input position

  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.7)
  local height = 8

  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "text")
  vim.b[buf].blink_disable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { prompt, "" })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  })
  vim.api.nvim_win_set_cursor(win, { 2, 0 })

  callbacks[buf] = on_submit
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function() callbacks[buf] = nil end,
  })

  local function set_input(text)
    local input_lines = vim.split(text, "\n")
    vim.api.nvim_buf_set_lines(buf, 1, -1, false, input_lines)
    vim.api.nvim_win_set_cursor(win, { 2, #input_lines[1] })
  end

  local function submit()
    local lines = vim.api.nvim_buf_get_lines(buf, 1, -1, false)
    local input = table.concat(lines, "\n")
    local cb = callbacks[buf]
    callbacks[buf] = nil
    vim.api.nvim_win_close(win, true)
    if action_id and input ~= "" then
      prompt_history[action_id] = prompt_history[action_id] or {}
      local h = prompt_history[action_id]
      table.insert(h, input)
      if #h > HISTORY_MAX then table.remove(h, 1) end
    end
    if cb then
      cb(input)
    end
  end

  local function cancel()
    callbacks[buf] = nil
    vim.api.nvim_win_close(win, true)
    vim.notify("[ai_tools] Cancelled.", vim.log.levels.INFO)
  end

  vim.keymap.set("i", "<CR>", submit, { buffer = buf, noremap = true, silent = true })
  vim.keymap.set("n", "<CR>", submit, { buffer = buf, noremap = true, silent = true })
  vim.keymap.set("n", "<Esc>", cancel, { buffer = buf, noremap = true, silent = true })
  vim.keymap.set("n", "q", cancel, { buffer = buf, noremap = true, silent = true })

  vim.keymap.set("n", "k", function()
    hist_idx = math.max(1, hist_idx - 1)
    set_input(history[hist_idx] or "")
  end, { buffer = buf, noremap = true, silent = true })

  vim.keymap.set("n", "j", function()
    hist_idx = math.min(#history + 1, hist_idx + 1)
    set_input(history[hist_idx] or "")
  end, { buffer = buf, noremap = true, silent = true })

  vim.cmd("startinsert")
end

function M.display_error(message)
  vim.notify(message, vim.log.levels.ERROR)
end

return M
