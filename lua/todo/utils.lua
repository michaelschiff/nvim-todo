local M = {}

-- any line starting with '#' is a heading -- if you care about rendering as markdow you can use 
-- more than one for smaller text
function M.isHeading(s)
	return string.sub(s, 1, 1) == "#"
end

-- any line that starts as a markdown list item is a task.  tasks can only be a single line
function M.isTask(s)
	return string.sub(s, 1, 1) == "-"
end

function M.isChecked(l)
	return string.sub(l, 1, 5) == "- [x]"
end

function M.isDoneGroupHeading(s)
	return string.sub(s, 1, 6) == "# DONE"
end

function M.getLine(i)
	return table.concat(vim.api.nvim_buf_get_lines(0, i, i+1, false))
end

function M.highlight(namespace_id, current_buf, line_num, line_len)
	local start_col = 0 -- this is always 0 just nice to know what the 0 means
	-- start_row and end_row are inclusive, so both set to the line we want to highlight
	vim.api.nvim_buf_set_extmark(current_buf, namespace_id, line_num, start_col,
		{ end_row = line_num, end_col = line_len, hl_group = 'HighlightLine' })
end

function M.getCursorWord() return vim.fn.escape(vim.fn.expand('<cword>'), [[\/\#]]) end

return M
