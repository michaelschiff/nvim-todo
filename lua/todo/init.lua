local M = {}
local namespace_id

function M.setup(opt)
	return M
end

local function isHeading(s)
	return string.sub(s, 1, 1) == "#"
end

local function highlight(current_buf, line_num, line_len)
	local start_col = 0 -- this is always 0 just nice to know what the 0 means
	-- start_row and end_row are inclusive, so both set to the line we want to highlight
	vim.api.nvim_buf_set_extmark(current_buf, namespace_id, line_num, start_col,
		{ end_row = line_num, end_col = line_len, hl_group = 'HighlightLine' })
end

local function highlightHeadings()
	local current_buf = vim.api.nvim_get_current_buf()
	--local line_one = vim.api.nvim_buf_get_lines(current_buf, 0, 1, false)[1]
	--highlight(current_buf, 0, string.len(line_one))
	for i = 0, vim.api.nvim_buf_line_count(current_buf), 1 do
		local lineContent = table.concat(vim.api.nvim_buf_get_lines(0, i, i + 1, false))
		if isHeading(lineContent) then highlight(current_buf, i, string.len(lineContent)) end
	end
end


function M.init()
	vim.api.nvim_command(
		'highlight default HighlightLine guifg=#ff007c gui=bold ctermfg=198 cterm=bold ctermbg=darkgreen')
	namespace_id = vim.api.nvim_create_namespace('HighlightLineNamespace')
	highlightHeadings()
end

vim.api.nvim_create_augroup('HighlightLine', {})
vim.api.nvim_create_autocmd('BufRead', {
	pattern = 'TODO.txt',
	group = 'HighlightLine',
	callback = M.init
})


-- BufWritePre
function M.printLists()
	local buffer_to_string = function()
		local content = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), false)
		return table.concat(content, "\n")
	end
	print(buffer_to_string())
end

--vim.api.nvim_create_augroup('AutoFormatting', {})
--vim.api.nvim_create_autocmd('BufWritePre', {
--  pattern = 'TODO.txt',
--  group = 'AutoFormatting',
--  callback = M.printLists
--})

return M
