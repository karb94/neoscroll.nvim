table = require('table')
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


-- Table that maps keys to their corresponding function
local map_functions = {}
map_functions['<C-u>'] = 'scroll'
map_functions['<C-d>'] = 'scroll'
map_functions['<C-b>'] = 'scroll'
map_functions['<C-f>'] = 'scroll'
map_functions['<C-y>'] = 'scroll'
map_functions['<C-e>'] = 'scroll'
map_functions['zt']    = 'zt'
map_functions['zz']    = 'zz'
map_functions['zb']    = 'zb'


-- Helper function for mapping keys
function config.map(key, args)
    local args_str = table.concat(args, ', ')
    local require= [[lua require('neoscroll').]]
    local lua_cmd = require .. map_functions[key] .. '(' .. args_str .. ')'
    local cmd = '<cmd>' .. lua_cmd .. '<CR>'
    local opts = {silent=true, noremap=true}
    vim.api.nvim_set_keymap('n', key, cmd, opts)
    vim.api.nvim_set_keymap('x', key, cmd, opts)
end


-- Default mappings
function config.default_mappings()
    config.map('<C-u>', {'-vim.wo.scroll', 'true', '8'})
    config.map('<C-d>', { 'vim.wo.scroll', 'true', '8'})
    config.map('<C-b>', {'-vim.api.nvim_win_get_height(0)', 'true', '7'})
    config.map('<C-f>', { 'vim.api.nvim_win_get_height(0)', 'true', '7'})
    config.map('<C-y>', {'-0.10', 'false', '20'})
    config.map('<C-e>', { '0.10', 'false', '20'})
    config.map('zt', {'7'})
    config.map('zz', {'7'})
    config.map('zb', {'7'})
end


return config
