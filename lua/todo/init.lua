local M = {}
local namespace_id

function M.setup(opt)
    return M
end

-- BufRead
local function highlight()
  local current_buf = vim.api.nvim_get_current_buf()
  local line_one = vim.api.nvim_buf_get_lines(current_buf, 0, 1, false)[1]

  vim.api.nvim_buf_set_extmark(current_buf, namespace_id, 0, 0, {end_row = 0, end_col = string.len(line_one), hl_group='HighlightLine'})
end


function M.init()
   vim.api.nvim_command('highlight default HighlightLine guifg=#ff007c gui=bold ctermfg=198 cterm=bold ctermbg=darkgreen')
   namespace_id = vim.api.nvim_create_namespace('HighlightLineNamespace')
   highlight()
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

vim.api.nvim_create_augroup('AutoFormatting', {})
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = 'TODO.txt',
  group = 'AutoFormatting',
  callback = M.printLists 
})

return M
