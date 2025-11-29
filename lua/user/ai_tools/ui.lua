local history = require("user.ai_tools.history")

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
	-- Create a new buffer for the response
	local buf = create_buffer()
	local lines = vim.split(response, "\n")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- Open the response in the specified window type
	open_response_window(buf, window_type)
end

function M.get_user_prompt(instructions, enable_history, on_submit)
	local buf = vim.api.nvim_create_buf(false, true)
	local width = math.floor(vim.o.columns * 0.5)
	local height = 3

	-- Set buffer options
	vim.api.nvim_buf_set_option(buf, "buftype", "prompt")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "filetype", "text")

	-- Insert prompt message
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { instructions, "" })

	-- Open a floating window
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
	})

	-- Move cursor to the input line
	vim.api.nvim_win_set_cursor(win, { 2, 0 })

	-- Key mappings for history navigation in normal mode
	if enable_history then
		vim.api.nvim_buf_set_keymap(
			buf,
			"n",
			"k",
			':lua require("user.ai_tools.ui").history_prev(' .. buf .. ")<CR>",
			{ noremap = true, silent = true }
		)
		vim.api.nvim_buf_set_keymap(
			buf,
			"n",
			"j",
			':lua require("user.ai_tools.ui").history_next(' .. buf .. ")<CR>",
			{ noremap = true, silent = true }
		)
	end

	-- Map Enter key to submit the prompt
	vim.api.nvim_buf_set_keymap(
		buf,
		"i",
		"<CR>",
		'<Esc>:lua require("user.ai_tools.ui").submit_prompt(' .. buf .. ")<CR>",
		{ noremap = true, silent = true }
	)

	-- Store the callback in the callbacks table
	callbacks[buf] = on_submit

	-- History navigation functions
	function M.history_prev(bufnr)
		if M.current_index > 1 then
			M.current_index = M.current_index - 1
			local entry = history.get(M.current_index)
			if entry and entry.prompt then
				-- Split the prompt into lines if necessary
				local prompt_lines = vim.split(entry.prompt, "\n")
				vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, prompt_lines)
			else
				vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, { "" })
			end
		end
	end

	function M.history_next(bufnr)
		if M.current_index < history.count() then
			M.current_index = M.current_index + 1
			local entry = history.get(M.current_index)
			if entry and entry.prompt then
				-- Split the prompt into lines if necessary
				local prompt_lines = vim.split(entry.prompt, "\n")
				vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, prompt_lines)
			else
				vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, { "" })
			end
		else
			M.current_index = history.count() + 1
			vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, { "" })
		end
	end

	-- Function to handle prompt submission
	function M.submit_prompt(bufnr)
		local lines = vim.api.nvim_buf_get_lines(bufnr, 1, -1, false)
		local input = table.concat(lines, "\n")
		vim.api.nvim_win_close(win, true)
		if callbacks[bufnr] then
			callbacks[bufnr](input)
			callbacks[bufnr] = nil -- Remove the callback after execution
		end
	end

	-- Initialize history index
	M.current_index = history.count() + 1

	-- Enter insert mode automatically
	vim.cmd("startinsert")

	return
end

function M.display_error(message)
	vim.notify(message, vim.log.levels.ERROR)
end

return M
