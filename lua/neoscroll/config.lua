local config = {}

config.options = {
    no_mappings = false,
    hide_cursor = true,
    stop_eof = true,
    respect_scrolloff = false,
    cursor_scrolls_alone = true
}

-- Default options
function config.set_options(opts)
    opts = opts or {}
    for opt, _ in pairs(config.options) do
        if opts[opt] ~= nil then
            config.options[opt] = opts[opt]
        end
    end
end


-- Helper function for mapping keys
function config.map(keymap, lines, move_cursor, time_step)
    local args = lines .. ', ' .. move_cursor .. ', ' .. time_step
    local lua_cmd = [[lua require('neoscroll').scroll(]] .. args .. [[)<CR>]]
    vim.api.nvim_set_keymap('n', keymap, ':' .. lua_cmd, {silent=true})
    vim.api.nvim_set_keymap('x', keymap, '<cmd>' .. lua_cmd, {silent=true})
end


-- Default mappings
function config.default_mappings()
    config.map('<C-u>', '-vim.wo.scroll', 'true', '8')
    config.map('<C-d>',  'vim.wo.scroll', 'true', '8')
    config.map('<C-b>', '-vim.api.nvim_win_get_height(0)', 'true', '7')
    config.map('<C-f>',  'vim.api.nvim_win_get_height(0)', 'true', '7')
    config.map('<C-y>', '-0.10', 'false', '20')
    config.map('<C-e>',  '0.10', 'false', '20')
end


return config
