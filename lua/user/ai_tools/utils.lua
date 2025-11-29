local M = {}

function M.normalize_path(path)
	return path:gsub("\\", "/")
end

function M.copy_to_clipboard(text)
	vim.fn.setreg("+", text)
	print("Prompt copied to clipboard!")
end

function M.read_file(file_path)
	local normalized_path = M.normalize_path(file_path)

	local file = io.open(normalized_path, "r")
	if not file then
		return nil, "Could not open file: " .. normalized_path
	end

	local content = file:read("*all")
	file:close()

	return content
end

function M.chunk_text(text, chunk_size)
	if not text then
		return {}
	end

	local size = chunk_size or math.max(#text, 1)
	local chunks = {}
	local i = 1

	while i <= #text do
		table.insert(chunks, string.sub(text, i, i + size - 1))
		i = i + size
	end

	return chunks
end

return M
