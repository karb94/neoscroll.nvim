local config = require("neoscroll.config")
local utils = require("neoscroll.utils")
local opts
local so_scope

local scroll_timer = vim.loop.new_timer()
local target_line = 0
local relative_line = 0
local cursor_win_line
local scrolling = false
local continuous_scroll = false
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

-- excecute commands to scroll screen [and cursor] up/down one line
-- `execute` is necessary to allow the use of special characters like <C-y>
-- The bang (!) `normal!` in normal ignores mappings
local function scroll_up(data, scroll_window, scroll_cursor, n_repeat)
	local n = n_repeat == nil and 1 or n_repeat
	local cursor_scroll_input = scroll_cursor and string.rep("gk", n) or ""
	local window_scroll_input = scroll_window and [[\<C-y>]] or ""
	local scroll_input
	-- if scrolloff or window edge are going to move the cursor for you then only
	-- scroll the window
	if
		(
			(
				data.last_line_visible
				and data.win_lines_below_cursor == data.lines_below_cursor
				and data.lines_below_cursor <= utils.get_scrolloff()
			) or data.win_lines_below_cursor == utils.get_scrolloff()
		) and scroll_window
	then
		scroll_input = window_scroll_input
	else
		scroll_input = window_scroll_input .. cursor_scroll_input
	end
	return [[exec "normal! ]] .. scroll_input .. [["]]
end

local function scroll_down(data, scroll_window, scroll_cursor, n_repeat)
	local n = n_repeat == nil and 1 or n_repeat
	local cursor_scroll_input = scroll_cursor and string.rep("gj", n) or ""
	local window_scroll_input = scroll_window and [[\<C-e>]] or ""
	local scroll_input
	-- if scrolloff or window edge are going to move the cursor for you then only
	-- scroll the window
	if
		(
			(data.first_line_visible and data.win_lines_above_cursor <= utils.get_scrolloff())
			or data.win_lines_above_cursor <= utils.get_scrolloff()
		) and scroll_window
	then
		scroll_input = window_scroll_input
	else
		scroll_input = window_scroll_input .. cursor_scroll_input
	end
	return [[exec "normal! ]] .. scroll_input .. [["]]
end

-- Window rules for when to stop scrolling
local function window_reached_limit(data, move_cursor, direction)
	if data.last_line_visible and direction > 0 then
		if move_cursor then
      if opts.stop_eof and data.last_line_visible then
				return true
			elseif opts.respect_scrolloff and data.lines_below_cursor <= utils.get_scrolloff() then
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
local function cursor_reached_limit(data, direction)
	if data.first_line_visible and direction < 0 then
		if opts.respect_scrolloff and data.win_lines_above_cursor <= utils.get_scrolloff() then
			return true
		end
		return data.win_lines_above_cursor == 0
	elseif data.last_line_visible then
		if opts.respect_scrolloff and data.lines_below_cursor <= utils.get_scrolloff() then
			return true
		end
		return data.lines_below_cursor == 0
	end
end

-- Check if the window and the cursor can be scrolled further
local function who_scrolls(data, move_cursor, direction)
	local scroll_window, scroll_cursor
	local half_window = math.floor(data.window_height / 2)
	scroll_window = not window_reached_limit(data, move_cursor, direction)
	if not move_cursor then
		scroll_cursor = false
	elseif scroll_window then
		if utils.get_scrolloff() < half_window then
			scroll_cursor = true
		else
			scroll_cursor = false
		end
	elseif opts.cursor_scrolls_alone then
		scroll_cursor = not cursor_reached_limit(data, direction)
	else
		scroll_cursor = false
	end
	return scroll_window, scroll_cursor
end

-- Scroll one line in the given direction
local function scroll_one_line(lines_to_scroll, scroll_window, scroll_cursor, data)
	local winline_before = vim.fn.winline()
	local curpos_line_before = vim.api.nvim_win_get_cursor(0)[1]
	local scroll
	local scrolled_lines
	if lines_to_scroll > 0 then
		scrolled_lines = 1
		scroll = scroll_down
	else
		scrolled_lines = -1
		scroll = scroll_up
	end
	vim.cmd(scroll(data, scroll_window, scroll_cursor))
	-- Correct for wrapped lines
	local lines_behind = vim.fn.winline() - cursor_win_line
	if lines_to_scroll > 0 then
		lines_behind = -lines_behind
	end
	if scroll_cursor and scroll_window and lines_behind > 0 then
		vim.cmd(scroll(data, false, scroll_cursor, lines_behind))
	end
	if curpos_line_before == vim.api.nvim_win_get_cursor(0)[1] then
		-- if curpos_line didn't change, we can use it to get scrolled_lines
		-- This is more accurate when some lines are wrapped
		scrolled_lines = winline_before - vim.fn.winline()
	end
	relative_line = relative_line + scrolled_lines
end

-- Scrolling constructor
local function before_scrolling(lines, move_cursor, info)
	if opts.pre_hook ~= nil then
		opts.pre_hook(info)
	end
	-- Start scrolling
	scrolling = true
	-- Hide cursor line
	if opts.hide_cursor and move_cursor then
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
	target_line = lines
end

-- Scrolling destructor
local function stop_scrolling(move_cursor, info)
	if opts.hide_cursor == true and move_cursor then
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

	relative_line = 0
	target_line = 0
	scroll_timer:stop()
	scrolling = false
	continuous_scroll = false
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

-- Scrolling function
-- lines: number of lines to scroll or fraction of window to scroll
-- move_cursor: scroll the window and the cursor simultaneously
-- easing_function: name of the easing function to use for the scrolling animation
function neoscroll.scroll(lines, move_cursor, time, easing_function, info)
	-- If lines is a fraction of the window transform it to lines
	if utils.is_float(lines) then
		lines = utils.get_lines_from_win_fraction(lines)
	end
	if lines == 0 then
		return
	end
	-- If still scrolling just modify the amount of lines to scroll
	-- If the scroll is in the opposite direction and
	-- lines_to_scroll is longer than lines stop smoothly
	if scrolling then
		local lines_to_scroll = relative_line - target_line
		local opposite_direction = lines_to_scroll * lines > 0
		local long_scroll = math.abs(lines_to_scroll) - math.abs(lines) > 0
		if opposite_direction and long_scroll then
			target_line = relative_line - lines
		elseif continuous_scroll then
			target_line = relative_line + 2 * lines
		elseif math.abs(lines_to_scroll) > math.abs(5 * lines) then
			continuous_scroll = true
			relative_line = target_line - 2 * lines
		else
			target_line = target_line + lines
		end

		return
	end
	-- Check if the window and the cursor are allowed to scroll in that direction
	local data = utils.get_data()
	local half_window = math.floor(data.window_height / 2)
	if utils.get_scrolloff() >= half_window then
		cursor_win_line = half_window
	elseif data.win_lines_above_cursor <= utils.get_scrolloff() then
		cursor_win_line = utils.get_scrolloff() + 1
	elseif data.win_lines_below_cursor <= utils.get_scrolloff() then
		cursor_win_line = data.window_height - utils.get_scrolloff()
	else
		cursor_win_line = data.cursor_win_line
	end
	local scroll_window, scroll_cursor = who_scrolls(data, move_cursor, lines)
	-- If neither the window nor the cursor are allowed to scroll finish early
	if not scroll_window and not scroll_cursor then
		return
	end
	-- Preparation before scrolling starts
	before_scrolling(lines, move_cursor, info)
	-- If easing function is not specified default to easing_function
	local ef = easing_function and easing_function or opts.easing_function

	local lines_to_scroll = math.abs(relative_line - target_line)
	scroll_one_line(lines, scroll_window, scroll_cursor, data)
	if lines_to_scroll == 1 then
		stop_scrolling(move_cursor, info)
	end
	local time_step = compute_time_step(lines_to_scroll, lines, time, ef)
	local next_time_step = compute_time_step(lines_to_scroll - 1, lines, time, ef)
	local next_next_time_step = compute_time_step(lines_to_scroll - 2, lines, time, ef)
	-- Scroll the first line

	-- Callback function triggered by scroll_timer
	local function scroll_callback()
		lines_to_scroll = target_line - relative_line
		data = utils.get_data()
		scroll_window, scroll_cursor = who_scrolls(data, move_cursor, lines_to_scroll)
		if not scroll_window and not scroll_cursor then
			stop_scrolling(move_cursor, info)
			return
		end

		if math.abs(lines_to_scroll) > 2 and ef then
			local next_lines_to_scroll = math.abs(lines_to_scroll) - 2
			next_time_step = compute_time_step(next_lines_to_scroll, lines, time, ef)
			-- sets the repeat of the next cycle
			scroll_timer:set_repeat(next_time_step)
		end
		if math.abs(lines_to_scroll) == 0 then
			stop_scrolling(move_cursor, info)
			return
		end
		scroll_one_line(lines_to_scroll, scroll_window, scroll_cursor, data)
		if math.abs(lines_to_scroll) == 1 then
			stop_scrolling(move_cursor, info)
			return
		end
	end

	-- Start timer to scroll the rest of the lines
	scroll_timer:start(time_step, next_time_step, vim.schedule_wrap(scroll_callback))
	scroll_timer:set_repeat(next_next_time_step)
end

-- Wrapper for zt
function neoscroll.zt(half_screen_time, easing, info)
	local window_height = vim.api.nvim_win_get_height(0)
	local win_lines_above_cursor = vim.fn.winline() - 1
	-- Temporary fix for garbage values in local scrolloff when not set
	local lines = win_lines_above_cursor - utils.get_scrolloff()
	if lines == 0 then
		return
	end
	local corrected_time = math.floor(half_screen_time * (math.abs(lines) / (window_height / 2)) + 0.5)
	neoscroll.scroll(lines, false, corrected_time, easing, info)
end
-- Wrapper for zz
function neoscroll.zz(half_screen_time, easing, info)
	local window_height = vim.api.nvim_win_get_height(0)
	local lines = vim.fn.winline() - math.ceil(window_height / 2)
	if lines == 0 then
		return
	end
	local corrected_time = math.floor(half_screen_time * (math.abs(lines) / (window_height / 2)) + 0.5)
	neoscroll.scroll(lines, false, corrected_time, easing, info)
end
-- Wrapper for zb
function neoscroll.zb(half_screen_time, easing, info)
	local window_height = vim.api.nvim_win_get_height(0)
	local lines_below_cursor = window_height - vim.fn.winline()
	-- Temporary fix for garbage values in local scrolloff when not set
	local lines = -lines_below_cursor + utils.get_scrolloff()
	if lines == 0 then
		return
	end
	local corrected_time = math.floor(half_screen_time * (math.abs(lines) / (window_height / 2)) + 0.5)
	neoscroll.scroll(lines, false, corrected_time, easing, info)
end

function neoscroll.G(half_screen_time, easing, info)
	local lines = utils.get_lines_below(vim.fn.line("w$"))
	local window_height = vim.api.nvim_win_get_height(0)
	local cursor_win_line = vim.fn.winline()
	local win_lines_below_cursor = window_height - cursor_win_line
	local corrected_time = math.floor(half_screen_time * (math.abs(lines) / (window_height / 2)) + 0.5)
	neoscroll.scroll(lines, true, corrected_time, easing, { G = true })
end

function neoscroll.gg(half_screen_time, easing, info)
	local lines = utils.get_lines_above(vim.fn.line("w0"))
	local window_height = vim.api.nvim_win_get_height(0)
	local cursor_win_line = vim.fn.winline()
	lines = -lines - cursor_win_line
	local corrected_time = math.floor(half_screen_time * (math.abs(lines) / (window_height / 2)) + 0.5)
	neoscroll.scroll(lines, true, corrected_time, easing, info)
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
