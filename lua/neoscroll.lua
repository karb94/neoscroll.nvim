local scroll_timer = vim.loop.new_timer()
local lines_to_scroll = 0
local lines_scrolled = 0

-- UI variables
local guicursor


local scroll_up = function(move_cursor)
    return move_cursor and "k<C-y>" or "<C-y>"
end


local scroll_down = function(move_cursor)
    return move_cursor and "j<C-e>" or "<C-e>"
end


local hide_ui = function()
    if vim.o.termguicolors then
        guicursor = vim.o.guicursor
        vim.o.guicursor = guicursor .. ',a:Cursor/lCursor'
        vim.cmd('highlight Cursor blend=0')
    end
end


local restore_ui = function()
    if vim.o.termguicolors then
        vim.o.guicursor = guicursor
        vim.cmd('highlight Cursor blend=100')
    end
end

-- Checks whether the window edge matches the edge of the buffer
local at_buffer_edge = function(move_cursor)
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
local height_fraction = function(fraction)
    return vim.fn.float2nr(vim.fn.round(fraction * vim.api.nvim_win_get_height(0)))
end


-- Scrolling function
-- lines: number of lines to scroll or fraction of window to scroll
-- move_cursor: scroll and move the cursor in the same direction simultaneously 
local scroll = function(lines, move_cursor)

    -- If still scrolling just modify the amount of lines to move
    if lines_to_scroll ~= 0 then
        lines_to_scroll = lines_to_scroll + lines
        return
    end

    -- If at the top or bottom edges of the buffer don't scroll further
    edge = at_buffer_edge(move_cursor)
    if edge == "top" and lines > 0 then
        return
    elseif edge == "bottom" and lines < 0 then
        return
    end

    -- If lines is a a fraction of the window transform it to lines
    lines = vim.fn.abs(lines) < 1 and height_fraction(lines) or lines
    -- Hide some UI elements and assign the number of lines to scroll
    hide_ui()
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
    local scroll_callback = function()
        if lines_to_scroll == lines_scrolled or at_buffer_edge(move_cursor) then
            lines_scrolled = 0
            lines_to_scroll = 0
            scroll_timer:stop()
            restore_ui()
        elseif lines_to_scroll < lines_scrolled then
            lines_scrolled = lines_scrolled - 1
            vim.api.nvim_input(scroll_down(move_cursor))
        else
            lines_scrolled = lines_scrolled + 1
            vim.api.nvim_input(scroll_up(move_cursor))
        end
    end

    time_step = move_cursor and 8 or 20
    scroll_timer:start(time_step, time_step, vim.schedule_wrap(scroll_callback))

end

vim.api.nvim_set_keymap('n', '<C-u>', [[:lua require('neoscroll').scroll(vim.wo.scroll, true)<CR>]], {silent=true})
vim.api.nvim_set_keymap('n', '<C-d>', [[:lua require('neoscroll').scroll(-vim.wo.scroll, true)<CR>]], {silent=true})
-- vim.api.nvim_set_keymap('n', 'K', ':lua scroll(0.10, false)<CR>', {silent=true})
-- vim.api.nvim_set_keymap('n', 'J', ':lua scroll(-0.10, false)<CR>', {silent=true})

return {scroll = scroll}
