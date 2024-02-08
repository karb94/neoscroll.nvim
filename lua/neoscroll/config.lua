local config = {}

config.options = {
	mappings = { "<C-u>", "<C-d>", "<C-b>", "<C-f>", "<C-y>", "<C-e>", "zt", "zz", "zb" },
	hide_cursor = true,
	stop_eof = true,
	respect_scrolloff = false,
	cursor_scrolls_alone = true,
	performance_mode = false,
	time_scale = 1.0,
}

function config.set_options(custom_opts)
	config.options = vim.tbl_deep_extend("force", config.options, custom_opts or {})
end

config.easing_functions = {
	quadratic = function(x)
		return 1 - math.pow(1 - x, 1 / 2)
	end,
	cubic = function(x)
		return 1 - math.pow(1 - x, 1 / 3)
	end,
	quartic = function(x)
		return 1 - math.pow(1 - x, 1 / 4)
	end,
	quintic = function(x)
		return 1 - math.pow(1 - x, 1 / 5)
	end,
	circular = function(x)
		return 1 - math.pow(1 - x * x, 1 / 2)
	end,
	sine = function(x)
		return 2 * math.asin(x) / math.pi
	end,
}

local function generate_default_mappings(custom_mappings)
	custom_mappings = custom_mappings and custom_mappings or {}
	local defaults = {}
	defaults["<C-u>"] = { "scroll", { "-vim.wo.scroll", "true", "250" } }
	defaults["<C-d>"] = { "scroll", { "vim.wo.scroll", "true", "250" } }
	defaults["<C-b>"] = { "scroll", { "-vim.fn.winheight(0)", "true", "450" } }
	defaults["<C-f>"] = { "scroll", { "vim.fn.winheight(0)", "true", "450" } }
	defaults["<C-y>"] = { "scroll", { "-0.10", "false", "100" } }
	defaults["<C-e>"] = { "scroll", { "0.10", "false", "100" } }
	defaults["zt"] = { "zt", { "250" } }
	defaults["zz"] = { "zz", { "250" } }
	defaults["zb"] = { "zb", { "250" } }
	defaults["G"] = { "G", { "100" } }
	defaults["gg"] = { "gg", { "100" } }

	local t = {}
	local keys = config.options.mappings
	for i = 1, #keys do
		if defaults[keys[i]] ~= nil then
			t[keys[i]] = defaults[keys[i]]
		end
	end
	return t
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
