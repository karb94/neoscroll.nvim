local config = require("neoscroll.config")
local utils = require("neoscroll.utils")
local opts

-- Highlight group to hide the cursor
vim.api.nvim_exec(
	[[
augroup custom_highlight
autocmd!
autocmd ColorScheme * highlight NeoscrollHiddenCursor gui=reverse blend=100
augroup END
]],
	true
)
vim.cmd("highlight NeoscrollHiddenCursor gui=reverse blend=100")

local WindowState = {
	__index = function(state_table, winid)
		assert(type(winid) == type(0) and winid >= 0,
			"Expected a non-negative window id, got " .. tostring(winid)
		)
		local state = {
			winid = winid,
			scroll_timer = vim.loop.new_timer(),
			target_line = 0,
			relative_line = 0,
			cursor_win_line = nil, -- set inside scroll()
			scrolling = false,
			continuous_scroll = false,
			data = nil, -- set inside scroll()
			scrolloff = utils.get_scrolloff(winid, opts.use_local_scrolloff)
		}
		state_table[winid] = state
		return state
	end
}
setmetatable(WindowState, WindowState)

-- excecute commands to scroll screen [and cursor] up/down one line
-- The bang (!) `normal!` in normal ignores mappings
local function scroll_up(state, scroll_window, scroll_cursor, n_repeat)
	local n = n_repeat == nil and 1 or n_repeat
	local cursor_scroll_input = scroll_cursor and tostring(n) .. "gk" or ""
	local window_scroll_input = scroll_window and tostring(n) .. [[<C-y>]] or ""
	local data = state.data
	local scroll_input
	-- if scrolloff or window edge are going to move the cursor for you then only
	-- scroll the window
	if (
			(
					data.last_line_visible
							and data.win_lines_below_cursor == data.lines_below_cursor
							and data.lines_below_cursor <= state.scrolloff
					) or data.win_lines_below_cursor == state.scrolloff
			) and scroll_window
	then
		scroll_input = window_scroll_input
	else
		scroll_input = window_scroll_input .. cursor_scroll_input
	end
	utils.with_winid(state.winid, function()
		local escaped = vim.api.nvim_replace_termcodes(scroll_input, true, true, true)
		vim.api.nvim_cmd(
			{ cmd = "normal", bang = true, args = { escaped } },
			{ output = false }
		)
	end)
end

local function scroll_down(state, scroll_window, scroll_cursor, n_repeat)
	local n = n_repeat == nil and 1 or n_repeat
	local cursor_scroll_input = scroll_cursor and tostring(n) .. "gj" or ""
	local window_scroll_input = scroll_window and tostring(n) .. [[<C-e>]] or ""
	local data = state.data
	local scroll_input
	-- if scrolloff or window edge are going to move the cursor for you then only
	-- scroll the window
	if (
			(data.first_line_visible and data.win_lines_above_cursor <= state.scrolloff)
					or data.win_lines_above_cursor <= state.scrolloff
			) and scroll_window
	then
		scroll_input = window_scroll_input
	else
		scroll_input = window_scroll_input .. cursor_scroll_input
	end
	utils.with_winid(state.winid, function()
		local escaped = vim.api.nvim_replace_termcodes(scroll_input, true, true, true)
		vim.api.nvim_cmd(
			{ cmd = "normal", bang = true, args = { escaped } },
			{ output = false }
		)
	end)
end

-- Window rules for when to stop scrolling
local function window_reached_limit(state, move_cursor, direction)
	local data = state.data
	if data.last_line_visible and direction > 0 then
		if move_cursor then
			if opts.stop_eof and data.lines_below_cursor == data.win_lines_below_cursor then
				return true
			elseif opts.respect_scrolloff and data.lines_below_cursor <= state.scrolloff then
				return true
			else
				return data.lines_below_cursor == 0
			end
		else
			return data.lines_below_cursor == 0 and data.win_lines_above_cursor == 0
		end
	elseif data.first_line_visible and direction < 0 then
		return true
	else
		return false
	end
end

-- Cursor rules for when to stop scrolling
local function cursor_reached_limit(state)
	local data = state.data
	if data.first_line_visible then
		if opts.respect_scrolloff and data.win_lines_above_cursor <= state.scrolloff then
			return true
		end
		return data.win_lines_above_cursor == 0
	elseif data.last_line_visible then
		if opts.respect_scrolloff and data.lines_below_cursor <= state.scrolloff then
			return true
		end
		return data.lines_below_cursor == 0
	end
end

-- Check if the window and the cursor can be scrolled further
local function who_scrolls(state, move_cursor, direction)
	local data = state.data
	local scroll_window, scroll_cursor
	local half_window = math.floor(data.window_height / 2)
	scroll_window = not window_reached_limit(state, move_cursor, direction)
	if not move_cursor then
		scroll_cursor = false
	elseif scroll_window then
		if state.scrolloff < half_window then
			scroll_cursor = true
		else
			scroll_cursor = false
		end
	elseif opts.cursor_scrolls_alone then
		scroll_cursor = not cursor_reached_limit(state)
	else
		scroll_cursor = false
	end
	return scroll_window, scroll_cursor
end

-- Scroll one line in the given direction
local function scroll_one_line(lines_to_scroll, scroll_window, scroll_cursor, state)
	if lines_to_scroll > 0 then
		state.relative_line = state.relative_line + 1
		scroll_down(state, scroll_window, scroll_cursor)
		-- Correct for wrapped lines
		local lines_behind = state.cursor_win_line - utils.getwinline(state.winid)
		if scroll_cursor and scroll_window and lines_behind > 0 then
			scroll_down(state, false, scroll_cursor, lines_behind)
		end
	else
		state.relative_line = state.relative_line - 1
		scroll_up(state, scroll_window, scroll_cursor)
		-- Correct for wrapped lines
		local lines_behind = utils.getwinline(state.winid) - state.cursor_win_line
		if scroll_cursor and scroll_window and lines_behind > 0 then
			scroll_up(state, false, scroll_cursor, lines_behind)
		end
	end
end

-- Scrolling constructor
local function before_scrolling(winid, lines, move_cursor, info)
	if opts.pre_hook ~= nil then
		opts.pre_hook(info)
	end
	local state = WindowState[winid]
	-- Start scrolling
	state.scrolling = true
	-- Hide cursor line
	if opts.hide_cursor and move_cursor and winid == 0 then
		utils.hide_cursor()
	end
	-- Performance mode
	local performance_mode = vim.b.neoscroll_performance_mode or vim.g.neoscroll_performance_mode
	if performance_mode and move_cursor then
		if vim.g.loaded_nvim_treesitter then
			vim.cmd("TSBufDisable highlight")
		end
		vim.bo.syntax = "OFF"
	end
	-- Assign number of lines to scroll
	state.target_line = lines
end

-- Scrolling destructor
local function stop_scrolling(winid, move_cursor, info)
	-- Note: winid may not exist anymore
	if opts.hide_cursor == true and move_cursor and winid == 0 then
		utils.unhide_cursor()
	end
	--Performance mode
	local performance_mode = vim.b.neoscroll_performance_mode or vim.g.neoscroll_performance_mode
	if performance_mode and move_cursor then
		vim.bo.syntax = "ON"
		if vim.g.loaded_nvim_treesitter then
			vim.cmd("TSBufEnable highlight")
		end
	end
	if opts.post_hook ~= nil then
		opts.post_hook(info)
	end
	local state = WindowState[winid]
	-- window may be closed mid-scroll, and this would result in nil values
	if state ~= nil then
		state.scroll_timer:stop()
	end

	WindowState[winid] = nil
end

local function compute_time_step(lines_to_scroll, lines, time, easing_function)
	-- lines_to_scroll should always be positive
	-- If there's less than one line to scroll time_step doesn't matter
	if lines_to_scroll < 1 then
		return 1000
	end
	local lines_range = math.abs(lines)
	local ef = config.easing_functions[easing_function]
	local time_step
	-- If not yet in range return average time-step
	if not ef then
		time_step = math.floor(time / (lines_range - 1) + 0.5)
	elseif lines_to_scroll >= lines_range then
		time_step = math.floor(time * ef(1 / lines_range) + 0.5)
	else
		local x1 = (lines_range - lines_to_scroll) / lines_range
		local x2 = (lines_range - lines_to_scroll + 1) / lines_range
		time_step = math.floor(time * (ef(x2) - ef(x1)) + 0.5)
	end
	if time_step == 0 then
		time_step = 1
	end
	return time_step
end

local neoscroll = {}

local function callback_safe(fn, winid, move_cursor, info)
	local function cb()
		local ok, err = pcall(fn)
		if not ok then
			local ok2, err2 = pcall(stop_scrolling, winid, move_cursor, info)
			if not ok2 then
				local state = WindowState[winid]
				if state ~= nil then
					WindowState[winid].scroll_timer:stop()
				end
				-- something is horribly wrong if this happens
				vim.api.nvim_echo({
					{ "neoscroll shutdown error:", "ErrorMsg" },
					{ tostring(err2), "ErrorMsg" },
				}, true, {})
			end
			if type(err) ~= type("")
					or not err:lower():match("^.*invalid window id") then
				vim.api.nvim_echo({
					{ "neoscroll scrolling error:", "ErrorMsg" },
					{ tostring(err), "ErrorMsg" }
				}, true, {})
			end
		end
	end

	return cb
end

-- Callback function triggered by scroll_timer
local function scroll_callback(winid, lines, move_cursor, time, ef, info)
	local state = WindowState[winid]
	local lines_to_scroll = state.target_line - state.relative_line

	state.data = utils.get_data(winid)
	local scroll_window, scroll_cursor
	scroll_window, scroll_cursor = who_scrolls(
		state, move_cursor, lines_to_scroll
	)

	if not scroll_window and not scroll_cursor then
		stop_scrolling(winid, move_cursor, info)
		return
	end

	if math.abs(lines_to_scroll) > 2 and ef then
		local next_lines_to_scroll = math.abs(lines_to_scroll) - 2
		local next_time_step = compute_time_step(next_lines_to_scroll, lines, time, ef)
		-- sets the repeat of the next cycle
		state.scroll_timer:set_repeat(next_time_step)
	end
	if math.abs(lines_to_scroll) == 0 then
		stop_scrolling(winid, move_cursor, info)
		return
	end
	scroll_one_line(lines_to_scroll, scroll_window, scroll_cursor, state)
	if math.abs(lines_to_scroll) == 1 then
		stop_scrolling(winid, move_cursor, info)
		return
	end
end

-- Scrolling function
-- winid: id of the window to scroll (0 for current window)
-- lines: number of lines to scroll or fraction of window to scroll
-- move_cursor: scroll the window and the cursor simultaneously
-- easing_function: name of the easing function to use for the scrolling animation
function neoscroll.scroll_win(winid, lines, move_cursor, time, easing_function, info)
	local state = WindowState[winid]
	state.winid = winid
	-- If lines is a fraction of the window transform it to lines
	if utils.is_float(lines) then
		lines = utils.get_lines_from_win_fraction(winid, lines)
	end
	if lines == 0 then
		return
	end

	-- If still scrolling just modify the amount of lines to scroll
	-- If the scroll is in the opposite direction and
	-- lines_to_scroll is longer than lines stop smoothly
	if state.scrolling then
		local lines_to_scroll = state.relative_line - state.target_line
		local opposite_direction = lines_to_scroll * lines > 0
		local long_scroll = math.abs(lines_to_scroll) - math.abs(lines) > 0
		if opposite_direction and long_scroll then
			state.target_line = state.relative_line - lines
		elseif state.continuous_scroll then
			state.target_line = state.relative_line + 2 * lines
		elseif math.abs(lines_to_scroll) > math.abs(5 * lines) then
			state.continuous_scroll = true
			state.relative_line = state.target_line - 2 * lines
		else
			state.target_line = state.target_line + lines
		end

		return
	end

	-- Check if the window and the cursor are allowed to scroll in that direction
	state.data = utils.get_data(winid)
	local half_window = math.floor(state.data.window_height / 2)
	if state.scrolloff >= half_window then
		state.cursor_win_line = half_window
	elseif state.data.win_lines_above_cursor <= state.scrolloff then
		state.cursor_win_line = state.scrolloff + 1
	elseif state.data.win_lines_below_cursor <= state.scrolloff then
		state.cursor_win_line = state.data.window_height - state.scrolloff
	else
		state.cursor_win_line = state.data.cursor_win_line
	end

	local scroll_window, scroll_cursor = who_scrolls(state, move_cursor, lines)
	-- If neither the window nor the cursor are allowed to scroll finish early
	if not scroll_window and not scroll_cursor then
		return
	end
	-- Preparation before scrolling starts
	before_scrolling(winid, lines, move_cursor, info)
	-- If easing function is not specified default to easing_function
	local ef = easing_function and easing_function or opts.easing_function

	local lines_to_scroll = math.abs(state.relative_line - state.target_line)
	scroll_one_line(lines, scroll_window, scroll_cursor, state)
	if lines_to_scroll == 1 then
		stop_scrolling(winid, move_cursor, info)
	end
	local time_step = compute_time_step(lines_to_scroll, lines, time, ef)
	local next_time_step = compute_time_step(lines_to_scroll - 1, lines, time, ef)
	local next_next_time_step = compute_time_step(lines_to_scroll - 2, lines, time, ef)
	-- Scroll the first line

	-- Start timer to scroll the rest of the lines
	state.scroll_timer:start(
		time_step, next_time_step,
		vim.schedule_wrap(
			callback_safe(function()
				scroll_callback(winid, lines, move_cursor, time, ef, info)
			end,
				winid,
				move_cursor,
				info
			)
		)
	)
	state.scroll_timer:set_repeat(next_next_time_step)
end

function neoscroll.scroll(...)
	return neoscroll.scroll_win(0, ...)
end

-- Wrapper for zt
function neoscroll.zt_win(winid, half_screen_time, easing, info)
	local window_height = vim.api.nvim_win_get_height(winid)
	-- TODO figure out why this -2 is needed (also needed in master)
	--      one guess: because scrolloff is -1
	local win_lines_above_cursor = utils.getwinline(winid) - 1
	-- Temporary fix for garbage values in local scrolloff when not set
	local lines = win_lines_above_cursor - utils.get_scrolloff(winid, opts.use_local_scrolloff)
	if lines == 0 then
		return
	end
	local corrected_time = math.floor(
		half_screen_time * (math.abs(lines) / (window_height / 2)) + 0.5
	)
	neoscroll.scroll_win(winid, lines, false, corrected_time, easing, info)
end

function neoscroll.zt(half_screen_time, easing, info)
	return neoscroll.zt_win(0, half_screen_time, easing, info)
end

-- Wrapper for zz
function neoscroll.zz_win(winid, half_screen_time, easing, info)
	local window_height = vim.api.nvim_win_get_height(winid)
	local lines = utils.getwinline(winid) - math.floor(window_height / 2 + 1)
	if lines == 0 then
		return
	end
	local corrected_time = math.floor(
		half_screen_time * (math.abs(lines) / (window_height / 2)) + 0.5
	)
	neoscroll.scroll_win(winid, lines, false, corrected_time, easing, info)
end

function neoscroll.zz(half_screen_time, easing, info)
	return neoscroll.zz_win(0, half_screen_time, easing, info)
end

-- Wrapper for zb
function neoscroll.zb_win(winid, half_screen_time, easing, info)
	local window_height = vim.api.nvim_win_get_height(winid)
	local lines_below_cursor = window_height - utils.getwinline(winid)
	-- Temporary fix for garbage values in local scrolloff when not set
	local lines = -lines_below_cursor + utils.get_scrolloff(winid, opts.use_local_scrolloff)
	if lines == 0 then
		return
	end
	local corrected_time = math.floor(
		half_screen_time * (math.abs(lines) / (window_height / 2)) + 0.5
	)
	neoscroll.scroll(lines, false, corrected_time, easing, info)
end

function neoscroll.zb(half_screen_time, easing, info)
	return neoscroll.zb_win(0, half_screen_time, easing, info)
end

function neoscroll.G_win(winid, half_screen_time, easing, info)
	local lines = utils.get_lines_below(winid, utils.getline(winid, "w$"))
	local window_height = vim.api.nvim_win_get_height(winid)
	local corrected_time = math.floor(half_screen_time * (math.abs(lines) / (window_height / 2)) + 0.5)
	neoscroll.scroll(lines, true, corrected_time, easing, { G = true })
end

function neoscroll.G(half_screen_time, easing, info)
	return neoscroll.G_win(0, half_screen_time, easing, info)
end

function neoscroll.gg_win(winid, half_screen_time, easing, info)
	local lines = utils.get_lines_above(winid, utils.getline(winid, "w0"))
	local window_height = vim.api.nvim_win_get_height(winid)
	local cursor_win_line = utils.getwinline(winid)
	lines = -lines - cursor_win_line
	local corrected_time = math.floor(half_screen_time * (math.abs(lines) / (window_height / 2)) + 0.5)
	neoscroll.scroll_win(winid, lines, true, corrected_time, easing, info)
end

function neoscroll.gg(half_screen_time, easing, info)
	return neoscroll.gg_win(0, half_screen_time, easing, info)
end

function neoscroll.setup(custom_opts)
	config.set_options(custom_opts)
	opts = require("neoscroll.config").options
	require("neoscroll.config").set_mappings()
	vim.cmd("command! NeoscrollEnablePM let b:neoscroll_performance_mode = v:true")
	vim.cmd("command! NeoscrollDisablePM let b:neoscroll_performance_mode = v:false")
	vim.cmd("command! NeoscrollEnableBufferPM let b:neoscroll_performance_mode = v:true")
	vim.cmd("command! NeoscrollDisableBufferPM let b:neoscroll_performance_mode = v:false")
	vim.cmd("command! NeoscrollEnableGlobalPM let g:neoscroll_performance_mode = v:true")
	vim.cmd("command! NeoscrollDisablGlobalePM let g:neoscroll_performance_mode = v:false")
	if opts.performance_mode then
		vim.g.neoscroll_performance_mode = true
	end
end

return neoscroll
