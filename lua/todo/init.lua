local M = {
	PRDescriptionHandle = nil,
}

local config = {
	repo_template = "",
	users = {},
}

M.config = config

local utils = require("todo.utils")

local namespace_id
local this_win
local this_buf
local info_buf = vim.api.nvim_create_buf(false, true)
local prs_buf = vim.api.nvim_create_buf(false, true)

local tasks = {}
local sections = {
	headers = {},
	done_section_header = nil,
}

local function reset()
	tasks = {}
	sections.headers = {}
	sections.done_section_header = nil
end


local function parse()
	for i = 0, vim.api.nvim_buf_line_count(this_buf), 1 do
		local lineContent = utils.getLine(i)
		if utils.isHeading(lineContent) then
			local h = {lineNumber = i, lineLen = string.len(lineContent)}
			table.insert(sections.headers, h)
			if utils.isDoneGroupHeading(lineContent) then
				sections.done_section_header = h
			end
		end
		if utils.isTask(lineContent) then
			table.insert(tasks, {lineNumber = i, lineLen = string.len(lineContent)})
		end
	end
end

local function highlight()
	for _, v in pairs(sections.headers) do
		utils.highlight(namespace_id, this_buf, v.lineNumber, v.lineLen)
	end
end

function M.BufRead()
	vim.api.nvim_command('highlight default HighlightLine guifg=#cf007c gui=bold ctermfg=198 cterm=bold ctermbg=darkgreen')
	namespace_id = vim.api.nvim_create_namespace('nvim-todo')
	this_buf = vim.api.nvim_get_current_buf()
	this_win = vim.api.nvim_get_current_win()
	parse()
	highlight()
end

function M.BufWritePre()
	reset()
	parse()
	if sections.done_section_header == nil then return end
	local toMoveCount = 0
	local toMove = {}
	for i = 0, vim.api.nvim_buf_line_count(this_buf), 1 do
		local lineContent = utils.getLine(i)
		if utils.isChecked(lineContent) and i < sections.done_section_header.lineNumber then
			toMoveCount = toMoveCount + 1
			table.insert(toMove, i)
		end
	end
	-- reverse so that we dont change the line numbers of the lines we still need to delete
	table.sort(toMove, function(x, y) return x > y end)
	for _, v in pairs(toMove) do
		local line = utils.getLine(v)
		-- delete the line we are moving, this changes the line numbers of everything below, but nothing above,
		-- which we still have to move
		vim.api.nvim_buf_set_lines(this_buf, v, v+1, false, {nil})
		-- dgs is further down than the line we removed, so its line number is less by one
		sections.done_section_header.lineNumber = sections.done_section_header.lineNumber - 1;
		-- replace the DONE heading, with the itself and the completed line.
		-- i.e. insert the deleted line after the DONE heading
		vim.api.nvim_buf_set_lines(this_buf, sections.done_section_header.lineNumber, sections.done_section_header.lineNumber+1, false, {utils.getLine(sections.done_section_header.lineNumber), line})
	end
	reset()
	parse()
	highlight()
end

function M.runCMD(cmd, keep_output)
	local info = nil
	local handle = io.popen(cmd)
	if handle == nil then
		info = "<>"
	else
		info = handle:read("*a")
		handle:close()
	end
	local info_lines = {}
	if keep_output then
		for info_line in string.gmatch(info, "[^\r\n]+") do
			table.insert(info_lines, info_line)
		end
	end
	return info_lines
end

function M.getPRDescription(pr_num)
	return M.runCMD(string.format("gh pr view %s -q=\".title, .state, .body\" --json=\"title,body,state\"", M.config.repo_template .. "/" .. pr_num), true)
end

function M.getUserPRs(user)
	return M.runCMD(string.format("gh pr list -A %s", user), true)
end

--TODO(michaelschiff): changing focus back to the main window should trigger toggle close of the info window
function M.toggleDescription()
	if M.PRDescriptionHandle == nil or not vim.api.nvim_win_is_valid(M.PRDescriptionHandle) then
		local info_lines = M.getPRDescription(utils.getCursorWord())

		local windows = vim.api.nvim_list_wins()
		local totalWidth = 0
		for _, v in pairs(windows) do
			totalWidth = totalWidth + vim.api.nvim_win_get_width(v)
		end
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

function M.openPRLink()
	io.popen(string.format("open %s", M.config.repo_template .. "/" .. utils.getCursorWord()))
end

function M.setup(args)
	M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

function M.openAllUserPRs()
	local all_prs = {}
	for _, user in pairs(M.config.users) do
		for _,  pr in pairs(M.getUserPRs(user)) do
			table.insert(all_prs, pr)
		end
	end
	vim.api.nvim_buf_set_lines(prs_buf, 0, -1, true, all_prs)
	vim.api.nvim_open_win(prs_buf, false, {win=this_win, split='below'})
end


vim.api.nvim_create_augroup('nvim-todo', {})
vim.api.nvim_create_autocmd('BufRead', {
	pattern = 'TODO.txt',
	group = 'nvim-todo',
	callback = M.BufRead
})
vim.api.nvim_create_autocmd('BufWritePre', {
	pattern = 'TODO.txt',
	group = 'nvim-todo',
	callback = M.BufWritePre
})

return M
