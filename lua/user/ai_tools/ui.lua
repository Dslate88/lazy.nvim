local M = {}
local callbacks = {}

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

function M.display_response(response, window_type)
  local buf = create_buffer()
  local lines = vim.split(response or "", "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  open_response_window(buf, window_type)
end

---Prompt the user for input.
---@param opts table { prompt?, instructions? }
---@param on_submit fun(input:string)
function M.get_user_prompt(opts, on_submit)
  local prompt = opts.prompt or opts.instructions or "Enter input:"

  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.5)
  local height = 3

  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "text")
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

  local function submit()
    local lines = vim.api.nvim_buf_get_lines(buf, 1, -1, false)
    local input = table.concat(lines, "\n")
    vim.api.nvim_win_close(win, true)
    local cb = callbacks[buf]
    callbacks[buf] = nil
    if cb then
      cb(input)
    end
  end

  vim.keymap.set("i", "<CR>", submit, { buffer = buf, noremap = true, silent = true })

  vim.cmd("startinsert")
end

function M.display_error(message)
  vim.notify(message, vim.log.levels.ERROR)
end

return M
