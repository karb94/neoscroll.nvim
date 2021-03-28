local math = require('math')
local scroll_timer = vim.loop.new_timer()
local lines_to_scroll = 0
local lines_scrolled = 0
local scrolling = false

-- UI variables
local guicursor
local cursorline

-- Input to scroll screen [and cursor] up one line
local function scroll_up(move_cursor)
    return move_cursor and "k<C-y>" or "<C-y>"
end


-- Input to scroll screen [and cursor] down one line
local function scroll_down(move_cursor)
    return move_cursor and "j<C-e>" or "<C-e>"
end


-- Hide cursor and cursor line during scrolling for a better visual effect
local function hide_cursor_line()
    cursorline = vim.wo.cursorline
    vim.wo.cursorline = false
    if vim.o.termguicolors then
        guicursor = vim.o.guicursor
        vim.o.guicursor = guicursor .. ',a:Cursor/lCursor'
        vim.cmd('highlight Cursor blend=100')
    end
end


-- Restore hidden cursor line during scrolling
local function restore_cursor_line()
    vim.wo.cursorline = cursorline
    if vim.o.termguicolors then
        vim.o.guicursor = guicursor
        vim.cmd('highlight Cursor blend=0')
    end
end


-- Checks whether the window edge matches the edge of the buffer
local function at_buffer_edge(move_cursor)
    local buffer_lines = vim.api.nvim_buf_line_count(0)
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local window_height = vim.api.nvim_win_get_height(0)
    local cursor_height = vim.fn.winline() -- 1 is the top of the window

    local lowest_line = cursor_line + window_height - cursor_height
    local at_top_edge = cursor_height == cursor_line
    local at_bottom_edge = lowest_line == buffer_lines
    if at_top_edge then
        return "top"
    elseif at_bottom_edge and move_cursor then
        return "bottom"
    else
        return false
    end
end


-- Transforms fraction of window to number of lines
local function height_fraction(fraction)
    return vim.fn.float2nr(vim.fn.round(fraction * vim.api.nvim_win_get_height(0)))
end


neoscroll = {}


-- Scrolling function
-- lines: number of lines to scroll or fraction of window to scroll
-- move_cursor: scroll and move the cursor in the same direction simultaneously 
-- visual_mode: set to true if mapping in visual mode
neoscroll.scroll = function(lines, move_cursor, visual_mode)
    -- Restore selection if in visual mode
    if visual_mode then vim.cmd('normal gv') end

    -- If at the top or bottom edges of the buffer don't scroll further
    edge = at_buffer_edge(move_cursor)
    scroll_over_edge = (edge=="top" and lines>0) or (edge=="bottom" and lines<0)
    if scroll_over_edge then return end


    -- If lines is a a fraction of the window transform it to lines
    is_float = math.floor(math.abs(lines)) ~= math.abs(lines)
    print(is_float)
    if is_float then lines = height_fraction(lines) end

    -- If still scrolling just modify the amount of lines to scroll
    if scrolling then
        lines_to_scroll = lines_to_scroll + lines
        return
    end
    scrolling = true

    -- Hide cursor line 
    if vim.g.neoscroll_hide_cursor_line and move_cursor
        then hide_cursor_line()
    end

    --assign the number of lines to scroll
    lines_to_scroll = lines

    -- Scroll the first line
    if lines_to_scroll > 0 then
        vim.api.nvim_input(scroll_up(move_cursor))
        lines_scrolled = lines_scrolled + 1
    else
        vim.api.nvim_input(scroll_down(move_cursor))
        lines_scrolled = lines_scrolled - 1
    end

    -- Callback function triggered by scroll_timer
    local function scroll_callback()
        -- print('lines to scroll: ' .. lines_to_scroll)
        if lines_to_scroll == lines_scrolled or at_buffer_edge(move_cursor) then
            if vim.g.neoscroll_hide_cursor_line and move_cursor
                then restore_cursor_line()
            end
            lines_scrolled = 0
            lines_to_scroll = 0
            scroll_timer:stop()
            scrolling = false
        elseif lines_to_scroll < lines_scrolled then
            lines_scrolled = lines_scrolled - 1
            vim.api.nvim_input(scroll_down(move_cursor))
        else
            lines_scrolled = lines_scrolled + 1
            vim.api.nvim_input(scroll_up(move_cursor))
        end
    end

    time_step = move_cursor and vim.g.neoscroll_time_step_move_cursor
        or vim.g.neoscroll_time_step_no_move_cursor
    -- Start timer
    scroll_timer:start(time_step, time_step, vim.schedule_wrap(scroll_callback))

end


-- Default mappings
neoscroll.set_mappings = function()
    vim.api.nvim_set_keymap('n', '<C-u>', [[:lua neoscroll.scroll(vim.wo.scroll, true)<CR>]], {silent=true})
    vim.api.nvim_set_keymap('n', '<C-d>', [[:lua neoscroll.scroll(-vim.wo.scroll, true)<CR>]], {silent=true})
    vim.api.nvim_set_keymap('x', '<C-u>', [[:<C-u>lua neoscroll.scroll(vim.wo.scroll, true, true)<CR>]], {silent=true})
    vim.api.nvim_set_keymap('x', '<C-d>', [[:<C-u>lua neoscroll.scroll(-vim.wo.scroll, true, true)<CR>]], {silent=true})
    vim.api.nvim_set_keymap('n', 'K', ':lua neoscroll.scroll(0.10, false)<CR>', {silent=true})
    vim.api.nvim_set_keymap('n', 'J', ':lua neoscroll.scroll(-0.10, false)<CR>', {silent=true})
end


return neoscroll
