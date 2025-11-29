local M = {}

local log_file = vim.fn.stdpath("data") .. "/ai_tools.log"

function M.log(message, level)
	local lvl = level or "INFO"
	local log_entry = string.format("[%s] %s: %s", os.date("%Y-%m-%d %H:%M:%S"), lvl, message)
	local file, err = io.open(log_file, "a")

	if not file then
		print("Error opening log file: " .. (err or "Unknown error"))
		return
	end

	file:write(log_entry .. "\n")
	file:close()

	if vim and vim.notify then
		local severity = vim.log.levels[lvl] or vim.log.levels.INFO
		if severity >= vim.log.levels.ERROR then
			vim.notify(message, severity)
		end
	end
end

function M.info(message)
	M.log(message, "INFO")
end

function M.warn(message)
	M.log(message, "WARN")
end

function M.error(message)
	M.log(message, "ERROR")
end

return M
