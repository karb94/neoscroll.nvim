local opts = require('neoscroll.config').options
local scroll_timer = vim.loop.new_timer()
local target_line = 0
local current_line = 0
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
local function scroll_up(scroll_window, scroll_cursor)
    local cursor_scroll_input = scroll_cursor and 'gk' or ''
    local window_scroll_input = scroll_window and [[\<C-y>]] or ''
    local scroll_input = cursor_scroll_input .. window_scroll_input
    return [[exec "normal! ]] .. scroll_input .. [["]]
end
local function scroll_down(scroll_window, scroll_cursor)
    local cursor_scroll_input = scroll_cursor and 'gj' or ''
    local window_scroll_input = scroll_window and [[\<C-e>]] or ''
    local scroll_input = cursor_scroll_input .. window_scroll_input
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
local function get_data(lines_to_scroll)
    local data = {}
    -- If first line/last line not visible don't do anything else
    if lines_to_scroll < 0 then
        data.win_top_line = vim.fn.line("w0")
        data.first_line_visible = data.win_top_line == 1
        if not data.first_line_visible then
            return data
        end
    elseif lines_to_scroll > 0 then
        data.win_bottom_line = vim.fn.line("w$")
        data.last_line = vim.fn.line("$")
        data.last_line_visible = data.win_bottom_line == data.last_line
        if not data.last_line_visible then
            return data
        end
        data.window_height = vim.api.nvim_win_get_height(0)
        data.win_lines_below_cursor = data.window_height - vim.fn.winline()
        data.lines_below_cursor = get_lines_below_cursor()
    end
    data.lines_above_cursor = vim.fn.winline() - 1
    return data
end

-- Window rules for when to stop scrolling
local function window_reached_limit(data, move_cursor)
    if data.last_line_visible then
        if move_cursor then
            if opts.stop_eof and data.lines_below_cursor == data.win_lines_below_cursor then
                return true
            elseif opts.respect_scrolloff
                and data.lines_below_cursor <= vim.wo.scrolloff then
                return true
            else
                return data.lines_below_cursor == 0
            end
        else
            return data.lines_below_cursor == 0 and data.lines_above_cursor == 0
        end
    end
    return data.first_line_visible
end


-- Cursor rules for when to stop scrolling
local function cursor_reached_limit(data)
    if data.first_line_visible then
        if opts.respect_scrolloff
            and data.lines_above_cursor <= vim.wo.scrolloff then
            return true
        end
        return data.lines_above_cursor == 0
    elseif data.last_line_visible then
        if opts.respect_scrolloff and data.lines_below_cursor <= vim.wo.scrolloff then
            return true
        end
        return data.lines_below_cursor == 0
    end
end


-- Transforms fraction of window to number of lines
local function get_lines_from_win_fraction(fraction)
    local height_fraction = fraction * vim.api.nvim_win_get_height(0)
    return math.floor(height_fraction + 0.5)
end


-- Check if the window and the cursor can be scrolled further
local function who_scrolls(lines_to_scroll, move_cursor)
    local scroll_window, scroll_cursor, data
    data = get_data(lines_to_scroll)
    scroll_window = not window_reached_limit(data, move_cursor)
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
local function scroll_one_line(lines_to_scroll, scroll_window, scroll_cursor)
    if lines_to_scroll > 0 then
        current_line = current_line + 1
        vim.cmd(scroll_down(scroll_window, scroll_cursor))
    else
        current_line = current_line - 1
        vim.cmd(scroll_up(scroll_window, scroll_cursor))
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


local function compute_time_step(lines_to_scroll, lines, easing, time_step1, time_step2)
    local lines_to_scroll_abs = math.abs(lines_to_scroll)
    local lines_range = math.abs(lines)
    if lines_to_scroll_abs >= lines_range then return time_step1 end
    local x = (lines_range - lines_to_scroll_abs + 1) / lines_range
    local fraction = easing(x)
    return math.floor(time_step1 + (time_step2 - time_step1) * fraction + 0.5)
end


local neoscroll = {}


-- Scrolling function
-- lines: number of lines to scroll or fraction of window to scroll
-- move_cursor: scroll the window and the cursor simultaneously
-- time_step1: initial time-step between two single-line scrolls
-- time_step2: last time-step between two single-line scrolls
-- easing: easing function used to ease the scrolling animation
function neoscroll.scroll(lines, move_cursor, time_step1, time_step2, easing)
    -- If lines is a fraction of the window transform it to lines
    if is_float(lines) then
        lines = get_lines_from_win_fraction(lines)
    end
    -- If still scrolling just modify the amount of lines to scroll
    -- If the scroll is in the opposite direction and longer than lines stop
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
    local scroll_window, scroll_cursor = who_scrolls(lines, move_cursor)
    -- If neither the window nor the cursor are allowed to scroll finish early
    if not scroll_window and not scroll_cursor then return end
    -- Preparation before scrolling starts
    before_scrolling(lines, move_cursor)

    -- Callback function triggered by scroll_timer
    local function scroll_callback()
        local lines_to_scroll = target_line - current_line
        if lines_to_scroll == 0 then
            stop_scrolling(move_cursor)
            return
        end

        scroll_window, scroll_cursor = who_scrolls(lines_to_scroll, move_cursor)
        if not scroll_window and not scroll_cursor then
            stop_scrolling(move_cursor)
            return
        end

        if time_step2 ~= nil then
            local ef = easing and easing or opts.easing_function
            local timer_repeat = compute_time_step(lines_to_scroll, lines,
                ef, time_step1, time_step2)
            scroll_timer:set_repeat(timer_repeat)
        end
        scroll_one_line(lines_to_scroll, scroll_window, scroll_cursor)
    end

    -- Scroll the first line
    scroll_one_line(lines, scroll_window, scroll_cursor)
    -- Start timer to scroll the rest of the lines
    scroll_timer:start(time_step1, time_step1, vim.schedule_wrap(scroll_callback))
end


-- Wrapper for zt
function neoscroll.zt(time_step1, time_step2, easing)
    local window_height = vim.api.nvim_win_get_height(0)
    local lines_above_cursor = vim.fn.winline() - 1
    -- Temporary fix for garbage values in local scrolloff when not set
    local scrolloff = vim.wo.scrolloff < window_height and vim.wo.scrolloff or vim.o.scrolloff
    local lines = lines_above_cursor - scrolloff
    if lines == 0 then return end
    neoscroll.scroll(lines, false, time_step1, time_step2, easing)
end
-- Wrapper for zz
function neoscroll.zz(time_step1, time_step2, easing)
    local window_height = vim.api.nvim_win_get_height(0)
    local lines = vim.fn.winline() - math.floor(window_height/2)
    if lines == 0 then return end
    neoscroll.scroll(lines, false, time_step1, time_step2, easing)
end
-- Wrapper for zb
function neoscroll.zb(time_step1, time_step2, easing)
    local window_height = vim.api.nvim_win_get_height(0)
    local lines_below_cursor = window_height - vim.fn.winline()
    -- Temporary fix for garbage values in local scrolloff when not set
    local scrolloff = vim.wo.scrolloff < window_height and vim.wo.scrolloff or vim.o.scrolloff
    local lines = -lines_below_cursor + scrolloff
    if lines == 0 then return end
    neoscroll.scroll(lines, false, time_step1, time_step2, easing)
end


function neoscroll.setup(custom_opts)
    require('neoscroll.config').set_options(custom_opts)
    require('neoscroll.config').set_mappings()
    vim.cmd('command! NeoscrollEnablePM let b:neoscroll_performance_mode = v:true')
    vim.cmd('command! NeoscrollDisablePM let b:neoscroll_performance_mode = v:false')
end


return neoscroll
