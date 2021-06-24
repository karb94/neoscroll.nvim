local config = require('neoscroll.config')
local opts = require('neoscroll.config').options
local so_scope
if require('neoscroll.config').options.use_local_scrolloff then
    so_scope = 'wo'
else
    so_scope = 'go'
end

local scroll_timer = vim.loop.new_timer()
local target_line = 0
local current_line = 0
local cursor_win_line
local scrolling = false
local guicursor
-- Highlight group to hide the cursor
vim.api.nvim_exec([[
augroup custom_highlight
autocmd!
autocmd ColorScheme * highlight NeoscrollHiddenCursor gui=reverse blend=100
augroup END
]], true)
vim.cmd('highlight NeoscrollHiddenCursor gui=reverse blend=100')


-- Helper function to check if a number is a float
local function is_float(n)
    return math.floor(math.abs(n)) ~= math.abs(n)
end


-- excecute commands to scroll screen [and cursor] up/down one line
-- `execute` is necessary to allow the use of special characters like <C-y>
-- The bang (!) `normal!` in normal ignores mappings
local function scroll_up(data, scroll_window, scroll_cursor, n_repeat)
    local n = n_repeat == nil and 1 or n_repeat
    local cursor_scroll_input = scroll_cursor and string.rep('gk', n) or ''
    local window_scroll_input = scroll_window and [[\<C-y>]] or ''
    local scroll_input
    if ((data.last_line_visible
        and data.win_lines_below_cursor == data.lines_below_cursor
        and data.lines_below_cursor <= vim[so_scope].scrolloff)
        or data.win_lines_below_cursor == vim[so_scope].scrolloff) and scroll_window then
        scroll_input = window_scroll_input
    else
        scroll_input = window_scroll_input .. cursor_scroll_input
    end
    return [[exec "normal! ]] .. scroll_input .. [["]]
end


local function scroll_down(data, scroll_window, scroll_cursor, n_repeat)
    local n = n_repeat == nil and 1 or n_repeat
    local cursor_scroll_input = scroll_cursor and string.rep('gj', n) or ''
    local window_scroll_input = scroll_window and [[\<C-e>]] or ''
    local scroll_input
    if ((data.first_line_visible and data.win_lines_above_cursor <= vim[so_scope].scrolloff)
        or data.win_lines_above_cursor <= vim[so_scope].scrolloff) and scroll_window then
        scroll_input = window_scroll_input
    else
        scroll_input = window_scroll_input .. cursor_scroll_input
    end
    return [[exec "normal! ]] .. scroll_input .. [["]]
end


-- Hide cursor during scrolling for a better visual effect
local function hide_cursor()
    if vim.o.termguicolors and vim.o.guicursor ~= '' then
        guicursor = vim.o.guicursor
        vim.o.guicursor = 'a:NeoscrollHiddenCursor'
    end
end


-- Restore hidden cursor during scrolling
local function restore_cursor()
    if vim.o.termguicolors and vim.o.guicursor ~= '' then
        vim.o.guicursor = guicursor
    end
end


local function get_lines_below_cursor()
    local last_line = vim.fn.line("$")
    local lines_below_cursor = 0
    local line = vim.fn.line(".")
    local last_folded_line = vim.fn.foldclosedend(line)
    if last_folded_line ~= -1 then line = last_folded_line end
    while(line < last_line) do
        lines_below_cursor = lines_below_cursor + 1
        line = line + 1
        last_folded_line = vim.fn.foldclosedend(line)
        if last_folded_line ~= -1 then line = last_folded_line end
    end
    return lines_below_cursor
end


-- Collect all the necessary window, buffer and cursor data
-- vim.fn.line("w0") -> if there's a fold returns first line of fold
-- vim.fn.line("w$") -> if there's a fold returns last line of fold
local function get_data()
    local data = {}
    data.win_top_line = vim.fn.line("w0")
    data.win_bottom_line = vim.fn.line("w$")
    data.last_line = vim.fn.line("$")
    data.first_line_visible = data.win_top_line == 1
    data.last_line_visible = data.win_bottom_line == data.last_line
    data.window_height = vim.api.nvim_win_get_height(0)
    data.cursor_win_line = vim.fn.winline()
    data.win_lines_below_cursor = data.window_height - data.cursor_win_line
    data.win_lines_above_cursor = data.cursor_win_line - 1
    if data.last_line_visible then
        data.lines_below_cursor = get_lines_below_cursor()
    end
    return data
end

-- Window rules for when to stop scrolling
local function window_reached_limit(data, move_cursor, direction)
    if data.last_line_visible and direction > 0 then
        if move_cursor then
            if opts.stop_eof and data.lines_below_cursor == data.win_lines_below_cursor then
                return true
            elseif opts.respect_scrolloff
                and data.lines_below_cursor <= vim[so_scope].scrolloff then
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
local function cursor_reached_limit(data)
    if data.first_line_visible then
        if opts.respect_scrolloff
            and data.win_lines_above_cursor <= vim[so_scope].scrolloff then
            return true
        end
        return data.win_lines_above_cursor == 0
    elseif data.last_line_visible then
        if opts.respect_scrolloff and data.lines_below_cursor <= vim[so_scope].scrolloff then
            return true
        end
        return data.lines_below_cursor == 0
    end
end


-- Transforms fraction of window to number of lines
local function get_lines_from_win_fraction(fraction)
    local height_fraction = fraction * vim.api.nvim_win_get_height(0)
    local lines
    if height_fraction < 0 then
        lines = -math.floor(math.abs(height_fraction) + 0.5)
    else
        lines = math.floor(height_fraction + 0.5)
    end
    return lines
end


-- Check if the window and the cursor can be scrolled further
local function who_scrolls(data, move_cursor, direction)
    local scroll_window, scroll_cursor
    scroll_window = not window_reached_limit(data, move_cursor, direction)
    if not move_cursor then
        scroll_cursor = false
    elseif scroll_window then
        scroll_cursor = true
    elseif opts.cursor_scrolls_alone then
        scroll_cursor = not cursor_reached_limit(data)
    else
        scroll_cursor = false
    end
    return scroll_window, scroll_cursor
end


-- Scroll one line in the given direction
local function scroll_one_line(lines_to_scroll, scroll_window, scroll_cursor, data)
    if lines_to_scroll > 0 then
        current_line = current_line + 1
        vim.cmd(scroll_down(data, scroll_window, scroll_cursor))
        -- Correct for wrapped lines
        local lines_behind = cursor_win_line - vim.fn.winline()
        if scroll_cursor and scroll_window and lines_behind > 0 then
            vim.cmd(scroll_down(data, false, scroll_cursor, lines_behind))
        end
    else
        current_line = current_line - 1
        vim.cmd(scroll_up(data, scroll_window, scroll_cursor))
        -- Correct for wrapped lines
        local lines_behind = vim.fn.winline() - cursor_win_line
        if scroll_cursor and scroll_window and lines_behind > 0 then
            vim.cmd(scroll_up(data, false, scroll_cursor, lines_behind))
        end
    end
end


-- Scrolling constructor
local function before_scrolling(lines, move_cursor)
    -- Start scrolling
    scrolling = true
    -- Hide cursor line
    if opts.hide_cursor and move_cursor then
        hide_cursor()
    end
    -- Performance mode
    if vim.b.neoscroll_performance_mode and move_cursor then
        if vim.g.loaded_nvim_treesitter then
            vim.cmd('TSBufDisable highlight')
        end
        vim.bo.syntax = 'OFF'
    end
    -- Assign number of lines to scroll
    target_line = lines
end


-- Scrolling destructor
local function stop_scrolling(move_cursor)
    if opts.hide_cursor == true and move_cursor then
        restore_cursor()
    end
    --Performance mode
    if vim.b.neoscroll_performance_mode and move_cursor then
        vim.bo.syntax = 'ON'
        if vim.g.loaded_nvim_treesitter then
            vim.cmd('TSBufEnable highlight')
        end
    end

    current_line = 0
    target_line = 0
    scroll_timer:stop()
    scrolling = false
end


local function compute_time_step(lines_to_scroll, lines, time, easing_function)
    -- lines_to_scroll should always be positive
    -- If there's less than one line to scroll time_step doesn't matter
    if lines_to_scroll < 1 then return 1000 end
    local lines_range = math.abs(lines)
    local ef = config.easing_functions[easing_function]
    local time_step
    -- If not yet in range return average time-step
    if not ef then
        time_step = math.floor(time/(lines_range-1) + 0.5)
    elseif lines_to_scroll >= lines_range then
        time_step = math.floor(time*ef(1/lines_range) + 0.5)
    else
        local x1 = (lines_range - lines_to_scroll) / lines_range
        local x2 = (lines_range - lines_to_scroll + 1) / lines_range
        time_step = math.floor(time*(ef(x2) - ef(x1)) + 0.5)
    end
    if time_step == 0 then time_step = 1 end
    return time_step
end


local neoscroll = {}


-- Scrolling function
-- lines: number of lines to scroll or fraction of window to scroll
-- move_cursor: scroll the window and the cursor simultaneously
-- easing_function: name of the easing function to use for the scrolling animation
function neoscroll.scroll(lines, move_cursor, time, easing_function)
    -- If lines is a fraction of the window transform it to lines
    if is_float(lines) then
        lines = get_lines_from_win_fraction(lines)
    end
    if lines == 0 then return end
    -- If still scrolling just modify the amount of lines to scroll
    -- If the scroll is in the opposite direction and
    -- lines_to_scroll is longer than lines stop smoothly
    if scrolling then
        local lines_to_scroll = current_line - target_line
        local opposite_direction = lines_to_scroll * lines > 0
        local long_scroll = math.abs(lines_to_scroll) - math.abs(lines) > 0
        if opposite_direction and long_scroll then
            target_line = current_line - lines
        else
            target_line = target_line + lines
        end
        return
    end
    -- Check if the window and the cursor are allowed to scroll in that direction
    local data = get_data()
    if data.win_lines_above_cursor <= vim[so_scope].scrolloff then
        cursor_win_line = vim[so_scope].scrolloff + 1
    elseif data.win_lines_below_cursor <= vim[so_scope].scrolloff then
        cursor_win_line = data.window_height - vim[so_scope].scrolloff
    else
        cursor_win_line = data.cursor_win_line
    end
    local scroll_window, scroll_cursor = who_scrolls(data, move_cursor, lines)
    -- If neither the window nor the cursor are allowed to scroll finish early
    if not scroll_window and not scroll_cursor then return end
    -- Preparation before scrolling starts
    before_scrolling(lines, move_cursor)
    -- If easing function is not specified default to easing_function
    local ef = easing_function and easing_function or opts.easing_function

    local lines_to_scroll = math.abs(current_line - target_line)
    scroll_one_line(lines, scroll_window, scroll_cursor, data)
    if lines_to_scroll == 1 then stop_scrolling() end
    local time_step = compute_time_step(lines_to_scroll, lines, time, ef)
    local next_time_step = compute_time_step(lines_to_scroll-1, lines, time, ef)
    local next_next_time_step = compute_time_step(lines_to_scroll-2, lines, time, ef)
    -- Scroll the first line

    -- Callback function triggered by scroll_timer
    local function scroll_callback()
        lines_to_scroll = target_line - current_line
        local data = get_data()
        scroll_window, scroll_cursor = who_scrolls(data, move_cursor, lines_to_scroll)
        if not scroll_window and not scroll_cursor then
            stop_scrolling(move_cursor)
            return
        end

        if math.abs(lines_to_scroll) > 2 and ef then
            local next_lines_to_scroll = math.abs(lines_to_scroll) - 2
            next_time_step = compute_time_step(
                next_lines_to_scroll, lines, time, ef)
            -- sets the repeat of the next cycle
            scroll_timer:set_repeat(next_time_step)
        end
        scroll_one_line(lines_to_scroll, scroll_window, scroll_cursor, data)
        if math.abs(lines_to_scroll) == 1 then
            stop_scrolling(move_cursor)
            return
        end

    end

    -- Start timer to scroll the rest of the lines
    scroll_timer:start(time_step, next_time_step,
        vim.schedule_wrap(scroll_callback))
    scroll_timer:set_repeat(next_next_time_step)
end


-- Wrapper for zt
function neoscroll.zt(half_screen_time, easing)
    local window_height = vim.api.nvim_win_get_height(0)
    local win_lines_above_cursor = vim.fn.winline() - 1
    -- Temporary fix for garbage values in local scrolloff when not set
    local lines = win_lines_above_cursor - vim[so_scope].scrolloff
    if lines == 0 then return end
    local corrected_time = math.floor(
        half_screen_time * (math.abs(lines)/(window_height/2)) + 0.5)
    neoscroll.scroll(lines, false, corrected_time, easing)
end
-- Wrapper for zz
function neoscroll.zz(half_screen_time, easing)
    local window_height = vim.api.nvim_win_get_height(0)
    local lines = vim.fn.winline() - math.floor(window_height/2 + 1)
    if lines == 0 then return end
    local corrected_time = math.floor(
        half_screen_time * (math.abs(lines)/(window_height/2)) + 0.5)
    neoscroll.scroll(lines, false, corrected_time, easing)
end
-- Wrapper for zb
function neoscroll.zb(half_screen_time, easing)
    local window_height = vim.api.nvim_win_get_height(0)
    local lines_below_cursor = window_height - vim.fn.winline()
    -- Temporary fix for garbage values in local scrolloff when not set
    local lines = -lines_below_cursor + vim[so_scope].scrolloff
    if lines == 0 then return end
    local corrected_time = math.floor(
        half_screen_time * (math.abs(lines)/(window_height/2)) + 0.5)
    neoscroll.scroll(lines, false, corrected_time, easing)
end


function neoscroll.setup(custom_opts)
    require('neoscroll.config').set_options(custom_opts)
    require('neoscroll.config').set_mappings()
    vim.cmd('command! NeoscrollEnablePM let b:neoscroll_performance_mode = v:true')
    vim.cmd('command! NeoscrollDisablePM let b:neoscroll_performance_mode = v:false')
end


return neoscroll
