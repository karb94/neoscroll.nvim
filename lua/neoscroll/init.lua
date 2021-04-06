local opts = require('neoscroll.config').options
local scroll_timer = vim.loop.new_timer()
local lines_to_scroll = 0
local lines_scrolled = 0
local scrolling = false
local guicursor
-- Highlight group to hide the cursor
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
    if vim.o.termguicolors then
        guicursor = vim.o.guicursor
        vim.o.guicursor = guicursor .. ',a:NeoscrollHiddenCursor'
    end
end


-- Restore hidden cursor during scrolling
local function restore_cursor()
    if vim.o.termguicolors then
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
local function get_data(direction)
    local data = {}
    -- If first line/last line not visible don't do anything else
    if direction < 0 then
        data.win_top_line = vim.fn.line("w0")
        data.first_line_visible = data.win_top_line == 1
        if not data.first_line_visible then
            return data
        end
    elseif direction > 0 then
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
    return vim.fn.float2nr(vim.fn.round(height_fraction))
end


-- Check if the window and the cursor can be scrolled further
local function who_scrolls(direction, move_cursor)
    local scroll_window, scroll_cursor, data
    data = get_data(direction)
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
local function scroll_one_line(direction, scroll_window, scroll_cursor)
    if direction > 0 then
        lines_scrolled = lines_scrolled + 1
        vim.cmd(scroll_down(scroll_window, scroll_cursor))
    else
        lines_scrolled = lines_scrolled - 1
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
    lines_to_scroll = lines
end


-- Scrolling destructor
local function finish_scrolling(move_cursor)
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

    lines_scrolled = 0
    lines_to_scroll = 0
    scroll_timer:stop()
    scrolling = false
end


local neoscroll = {}


-- Scrolling function
-- lines: number of lines to scroll or fraction of window to scroll
-- move_cursor: scroll the window and the cursor simultaneously
-- time_step: time (in miliseconds) between one line scroll and the next one
function neoscroll.scroll(lines, move_cursor, time_step)
    -- If lines is a fraction of the window transform it to lines
    if is_float(lines) then
        lines = get_lines_from_win_fraction(lines)
    end
    -- If still scrolling just modify the amount of lines to scroll
    if scrolling then
        lines_to_scroll = lines_to_scroll + lines
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
        local direction = lines_to_scroll - lines_scrolled
        if direction == 0 then
            finish_scrolling(move_cursor)
        else
            scroll_window, scroll_cursor = who_scrolls(direction, move_cursor)
            if not scroll_window and not scroll_cursor then
                finish_scrolling(move_cursor)
            else
                scroll_one_line(direction, scroll_window, scroll_cursor)
            end
        end
    end

    -- Scroll the first line
    scroll_one_line(lines, scroll_window, scroll_cursor)
    -- Start timer to scroll the rest of the lines
    scroll_timer:start(time_step, time_step, vim.schedule_wrap(scroll_callback))
end


-- Wrapper for zt
function neoscroll.zt(time_step)
    local window_height = vim.api.nvim_win_get_height(0)
    local lines_above_cursor = vim.fn.winline() - 1
    -- Temporary fix for garbage values in local scrolloff when not set
    local scrolloff = vim.wo.scrolloff < window_height and vim.wo.scrolloff or vim.o.scrolloff
    local lines = lines_above_cursor - scrolloff
    if lines == 0 then return end
    neoscroll.scroll(lines, false, time_step)
end
-- Wrapper for zz
function neoscroll.zz(time_step)
    local window_height = vim.api.nvim_win_get_height(0)
    local lines = vim.fn.winline() - math.floor(window_height/2)
    if lines == 0 then return end
    neoscroll.scroll(lines, false, time_step)
end
-- Wrapper for zb
function neoscroll.zb(time_step)
    local window_height = vim.api.nvim_win_get_height(0)
    local lines_below_cursor = window_height - vim.fn.winline()
    -- Temporary fix for garbage values in local scrolloff when not set
    local scrolloff = vim.wo.scrolloff < window_height and vim.wo.scrolloff or vim.o.scrolloff
    local lines = -lines_below_cursor + scrolloff
    if lines == 0 then return end
    neoscroll.scroll(lines, false, time_step)
end


function neoscroll.setup(custom_opts)
    require('neoscroll.config').set_options(custom_opts)
    require('neoscroll.config').default_mappings()
    vim.cmd('command! NeoscrollEnablePM let b:neoscroll_performance_mode = v:true')
    vim.cmd('command! NeoscrollDisablePM let b:neoscroll_performance_mode = v:false')
end


return neoscroll
