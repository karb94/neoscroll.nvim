local config = {}

config.options = {
    mappings = {'<C-u>', '<C-d>', '<C-b>', '<C-f>', '<C-y>', '<C-e>',
        'zt', 'zz', 'zb'},
    hide_cursor = true,
    stop_eof = true,
    use_local_scrolloff = false,
    respect_scrolloff = false,
    cursor_scrolls_alone = true,
    easing_function = nil
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


config.easing_functions = {
    quadratic = function(x) return 1 - math.pow(1-x, 1/2)     end,
    cubic     = function(x) return 1 - math.pow(1-x, 1/3)     end,
    quartic   = function(x) return 1 - math.pow(1-x, 1/4)     end,
    quintic   = function(x) return 1 - math.pow(1-x, 1/5)     end,
    circular  = function(x) return 1 - math.pow(1-x*x, 1/2)   end,
    sine      = function(x) return 2 * math.asin(x) / math.pi end
}


config.key_to_function = {}

local function generate_default_mappings(custom_mappings)
    custom_mappings = custom_mappings and custom_mappings or {}
    local defaults = {}
    defaults['<C-u>'] = {'scroll', {'-vim.wo.scroll'                 , 'true' , '250'}}
    defaults['<C-d>'] = {'scroll', { 'vim.wo.scroll'                 , 'true' , '250'}}
    defaults['<C-b>'] = {'scroll', {'-vim.api.nvim_win_get_height(0)', 'true' , '450' }}
    defaults['<C-f>'] = {'scroll', { 'vim.api.nvim_win_get_height(0)', 'true' , '450' }}
    defaults['<C-y>'] = {'scroll', {'-0.10'                          , 'false', '100' }}
    defaults['<C-e>'] = {'scroll', { '0.10'                          , 'false', '100' }}
    defaults['zt']    = {'zt'    , {                                            '250' }}
    defaults['zz']    = {'zz'    , {                                            '250' }}
    defaults['zb']    = {'zb'    , {                                            '250' }}
    defaults['gg']  = {'scroll', {'-vim.fn.line(".")+1', 'true', '1500', [["cubic"]]}}
    defaults['G'] = {'scroll', {'vim.fn.line("$")-vim.fn.line(".")', 'true', '1500', [["cubic"]]}}

    local t = {}
    local keys = config.options.mappings
    for i=1, #keys do
        if defaults[keys[i]] ~= nil then
            t[keys[i]] = defaults[keys[i]]
        end
    end
    return t
end

-- Helper function for mapping keys
local function map_key(key, func, args)
    local args_str = table.concat(args, ', ')
    local prefix = [[lua require('neoscroll').]]
    local lua_cmd = prefix .. func .. '(' .. args_str .. ')'
    local cmd = '<cmd>' .. lua_cmd .. '<CR>'
    local opts = {silent=true, noremap=true}
    vim.api.nvim_set_keymap('n', key, cmd, opts)
    vim.api.nvim_set_keymap('x', key, cmd, opts)
end


-- Set mappings
function config.set_mappings(custom_mappings)
    if custom_mappings ~= nil then
        for key, val in pairs(custom_mappings) do
            map_key(key, val[1], val[2])
        end
    else
        local default_mappings = generate_default_mappings()
        for key, val in pairs(default_mappings) do
            map_key(key, val[1], val[2])
        end
    end
end


return config
