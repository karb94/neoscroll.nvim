local config = {}

config.default_options = {
  mappings = { "<C-u>", "<C-d>", "<C-b>", "<C-f>", "<C-y>", "<C-e>", "zt", "zz", "zb" },
  hide_cursor = true,
  stop_eof = true,
  respect_scrolloff = false,
  cursor_scrolls_alone = true,
  duration_multiplier = 1.0,
  performance_mode = false,
  easing = "linear",
  ignored_events = {'WinScrolled', 'CursorMoved'},
  telescope_scroll_opts = { duration = 250 },
}

config.opts = vim.deepcopy(config.default_options)

function config.set_options(custom_opts)
  for key, value in pairs(custom_opts) do
    config.opts[key] = value
  end
end

-- Helper function for mapping keys
local function map_key(key, func, args)
  local args_str = table.concat(args, ", ")
  local prefix = [[lua require('neoscroll').]]
  local lua_cmd = prefix .. func .. "(" .. args_str .. ")"
  local cmd = "<cmd>" .. lua_cmd .. "<CR>"
  local opts = { silent = true, noremap = true }
  vim.api.nvim_set_keymap("n", key, cmd, opts)
  vim.api.nvim_set_keymap("x", key, cmd, opts)
end

config.mappings_warning = true
-- Set mappings
function config.set_mappings(custom_mappings)
  if config.mappings_warning then
    local old_sig = "scroll(lines, move_cursor, time[, easing])"
    local new_sig = "scroll(lines, opts)"
    local custom_mappings_url = [[https://github.com/karb94/neoscroll.nvim?tab=readme-ov-file#custom-mappings]]
    local warning_msg = "Neoscroll: set_mappings() is deprecated. " ..
    "Use `:help neoscroll-helper-functions` to construct custom mappings. " ..
    "Examples are provided in the 'Custom mappings' section of the README."
    vim.notify(warning_msg, vim.log.levels.WARN, {title = 'Neoscroll'})
    config.mappings_warning = false
  end
  for key, val in pairs(custom_mappings) do
    map_key(key, val[1], val[2])
  end
end

return config
