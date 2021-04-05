table = require('table')
local config = {}

config.options = {
    mappings = {'<C-u>', '<C-d>', '<C-b>', '<C-f>', '<C-y>', '<C-e>', 'zt', 'zz', 'zb'},
    hide_cursor =   true,
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
local key_to_function = {}
key_to_function['<C-u>'] = {'scroll', {'-vim.wo.scroll', 'true', '8'                  }}
key_to_function['<C-d>'] = {'scroll', { 'vim.wo.scroll', 'true', '8'                  }}
key_to_function['<C-b>'] = {'scroll', {'-vim.api.nvim_win_get_height(0)', 'true', '7' }}
key_to_function['<C-f>'] = {'scroll', { 'vim.api.nvim_win_get_height(0)', 'true', '7' }}
key_to_function['<C-y>'] = {'scroll', {'-0.10', 'false', '20'                         }}
key_to_function['<C-e>'] = {'scroll', { '0.10', 'false', '20'                         }}
key_to_function['zt']    = {'zt',     {'7'                                            }}
key_to_function['zz']    = {'zz',     {'7'                                            }}
key_to_function['zb']    = {'zb',     {'7'                                            }}


-- Helper function for mapping keys
function config.map(key)
    local func = key_to_function[key][1]
    local args = key_to_function[key][2]
    local args_str = table.concat(args, ', ')
    local prefix = [[lua require('neoscroll').]]
    local lua_cmd = prefix .. func .. '(' .. args_str .. ')'
    local cmd = '<cmd>' .. lua_cmd .. '<CR>'
    local opts = {silent=true, noremap=true}
    vim.api.nvim_set_keymap('n', key, cmd, opts)
    vim.api.nvim_set_keymap('x', key, cmd, opts)
end


-- Default mappings
function config.default_mappings()
    for key, _ in pairs(key_to_function) do
        -- If key is in the mappings array map it
        for _, opt_key in ipairs(config.options.mappings) do
            if opt_key == key then
                config.map(key)
            end
        end
    end
end


return config
