local M = {
	PRDescriptionHandle = nil
}
local namespace_id
local this_buf

function M.setup(_)
	return M
end

local function isHeading(s)
	return string.sub(s, 1, 1) == "#"
end

local function isChecked(l)
	return string.sub(l, 1, 5) == "- [x]"
end

local function isDoneGroupHeading(s)
	return string.sub(s, 1, 6) == "# DONE"
end

local function getLine(i)
	return table.concat(vim.api.nvim_buf_get_lines(0, i, i+1, false))
end

local function getDoneGroupStart()
	for i = 0, vim.api.nvim_buf_line_count(this_buf), 1 do
		local lineContent = getLine(i)
		if isDoneGroupHeading(lineContent) then return i end
	end
	return nil
end

local function highlight(current_buf, line_num, line_len)
	local start_col = 0 -- this is always 0 just nice to know what the 0 means
	-- start_row and end_row are inclusive, so both set to the line we want to highlight
	vim.api.nvim_buf_set_extmark(current_buf, namespace_id, line_num, start_col,
		{ end_row = line_num, end_col = line_len, hl_group = 'HighlightLine' })
end

local function highlightHeadings()
	for i = 0, vim.api.nvim_buf_line_count(this_buf), 1 do
		local lineContent = getLine(i)
		if isHeading(lineContent) then highlight(this_buf, i, string.len(lineContent)) end
	end
end


function M.bufRead()
	vim.api.nvim_command('highlight default HighlightLine guifg=#cf007c gui=bold ctermfg=198 cterm=bold ctermbg=darkgreen')
	namespace_id = vim.api.nvim_create_namespace('HighlightLineNamespace')
	this_buf = vim.api.nvim_get_current_buf()
	highlightHeadings()
end

vim.api.nvim_create_augroup('HighlightLine', {})
vim.api.nvim_create_autocmd('BufRead', {
	pattern = 'TODO.txt',
	group = 'HighlightLine',
	callback = M.bufRead
})

vim.api.nvim_create_augroup('HandleCheckmark', {})
vim.api.nvim_create_autocmd('BufWritePre', {
	pattern = 'TODO.txt',
	group = 'HandleCheckmark',
	callback = function ()
		local dgs = getDoneGroupStart()
		if dgs == nil then return end
		local toMoveCount = 0
		local toMove = {}
		for i = 0, vim.api.nvim_buf_line_count(this_buf), 1 do
			local lineContent = getLine(i)
			if isChecked(lineContent) and i < dgs then
				toMoveCount = toMoveCount + 1
				table.insert(toMove, i)
			end
		end
		-- reverse so that we dont change the line numbers of the lines we still need to delete
		table.sort(toMove, function(x, y) return x > y end)
		for _, v in pairs(toMove) do
			local line = getLine(v)
			-- delete the line we are moving, this changes the line numbers of everything below, but nothing above,
			-- which we still have to move
			vim.api.nvim_buf_set_lines(this_buf, v, v+1, false, {nil})
			-- dgs is further down than the line we removed, so its line number is less by one
			dgs = dgs - 1;
			-- replace the DONE heading, with the itself and the completed line.
			-- i.e. insert the deleted line after the DONE heading
			vim.api.nvim_buf_set_lines(this_buf, dgs, dgs+1, false, {getLine(dgs), line})
		end
	highlightHeadings()
	end
})

function M.toggleDescription()
	-- TODO(michaelschiff): this doesn't correctly handle the case where the window is closed directly by the user
	-- e.g. if they :q in normal mode in that window
	if M.PRDescriptionHandle == nil then
		local windows = vim.api.nvim_list_wins()
		local totalWidth = 0
		for _, v in pairs(windows) do
			totalWidth = totalWidth + vim.api.nvim_win_get_width(v)
		end
		local width = 60
		M.PRDescriptionHandle = vim.api.nvim_open_win(0, true,
			{ relative = 'editor', row = 1, col = totalWidth - width, width = 60, height = 10, border = "shadow" })
	else
		vim.api.nvim_win_close(M.PRDescriptionHandle, true)
		M.PRDescriptionHandle = nil
	end
end

return M
