local M = {}
M.entries = {}

function M.add(prompt, response)
	table.insert(M.entries, { prompt = prompt, response = response })
end

function M.get(index)
	return M.entries[index]
end

function M.count()
	return #M.entries
end

return M
