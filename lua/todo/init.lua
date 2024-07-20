local M = {
	PRDescriptionHandle = nil,
}

local namespace_id
local this_buf
local info_buf = vim.api.nvim_create_buf(false, true)

function M.setup(_)
	return M
end

local function getCursorWord() return vim.fn.escape(vim.fn.expand('<cword>'), [[\/\#]]) end

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

--TODO(michaelschiff): changing focus back to the main window should trigger toggle close of the info window
function M.toggleDescription()
	-- TODO(michaelschiff): this doesn't correctly handle the case where the window is closed directly by the user
	-- e.g. if they :q in normal mode in that window. In this case PRDescriptionHandle will be non-nil, but the else
	-- condition will error because PRDescriptionHandle points to a closed window, so closing it again fails
	if M.PRDescriptionHandle == nil then
		local info = nil
		local handle = io.popen(string.format("gh pr view https://github.com/Arize-ai/arize/pull/%s -q=\".title, .body\" --json=\"title,body\"", getCursorWord()))
		if handle == nil then
			info = "<>"
		else
			info = handle:read("*a")
			handle:close()
		end
		local info_lines = {}
		for info_line in string.gmatch(info, "[^\r\n]+") do
			table.insert(info_lines, info_line)
		end

		local windows = vim.api.nvim_list_wins()
		local totalWidth = 0
		for _, v in pairs(windows) do
			totalWidth = totalWidth + vim.api.nvim_win_get_width(v)
		end
		local width = 60
		local cursor_r,cursor_c = unpack(vim.api.nvim_win_get_cursor(0))
		vim.api.nvim_buf_set_lines(info_buf, 0, -1, true, info_lines)

		-- col = totalWidth - width, # max of this and cursor_c + 5
		M.PRDescriptionHandle = vim.api.nvim_open_win(info_buf, true,
			{ relative = 'editor', row = cursor_r + 1, col = cursor_c, width = 80, height = 10, style = "minimal", border = "shadow", title="info"})
	else
		vim.api.nvim_win_close(M.PRDescriptionHandle, true)
		M.PRDescriptionHandle = nil
	end
end

return M
