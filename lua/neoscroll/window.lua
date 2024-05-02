---@class Data
---@field win_top_line integer Line number of the topmost line of the window
---@field win_bottom_line integer Line number of the bottommost line of the window
---@field last_line integer Last line of the file
---@field first_line_visible boolean First line is visible in the window
---@field last_line_visible boolean Last line is visible in the window
---@field window_height integer Height of the window
---@field cursor_win_line integer Row number of the cursor position in the window
---@field win_lines_below_cursor integer Number of window rows below the cursor
---@field win_lines_above_cursor integer Number of window rows above the cursor
---@field lines_below_cursor integer Number of lines below the cursor until the end of file or window
---@field win_bottom_line_eof boolean Bottommost line of the window is the last line of the file
---@field scrolloff integer Window scrolloff

local window = {}

function window.get_lines_above(line)
  local lines_above = 0
  local first_folded_line = vim.fn.foldclosed(line)
  if first_folded_line ~= -1 then
    line = first_folded_line
  end
  while line > 1 do
    lines_above = lines_above + 1
    line = line - 1
    first_folded_line = vim.fn.foldclosed(line)
    if first_folded_line ~= -1 then
      line = first_folded_line
    end
  end
  return lines_above
end

-- Calculate lines below the cursor till the EOF skipping folded lines
function window.get_lines_below(line)
  local last_line = vim.fn.line("$")
  local lines_below = 0
  local last_folded_line = vim.fn.foldclosedend(line)
  if last_folded_line ~= -1 then
    line = last_folded_line
  end
  while line < last_line do
    lines_below = lines_below + 1
    line = line + 1
    last_folded_line = vim.fn.foldclosedend(line)
    if last_folded_line ~= -1 then
      line = last_folded_line
    end
  end
  return lines_below
end

function window.scrolloff()
  local window_scrolloff = vim.wo.scrolloff
  if window_scrolloff == -1 then
    return vim.go.scrolloff
  else
    return window_scrolloff
  end
end

-- Collect all the necessary window, buffer and cursor data
-- vim.fn.line("w0") -> if there's a fold returns first line of fold
-- vim.fn.line("w$") -> if there's a fold returns last line of fold
---@return Data
local function get_data()
  local t = {
    win_top_line = vim.fn.line("w0"),
    win_bottom_line = vim.fn.line("w$"),
    last_line = vim.fn.line("$"),
    scrolloff = window.scrolloff(),
    window_height = vim.fn.winheight(0),
    cursor_win_line = vim.fn.winline(),
  }
  t.first_line_visible = t.win_top_line == 1
  t.last_line_visible = t.win_bottom_line == t.last_line
  t.win_lines_below_cursor = t.window_height - t.cursor_win_line
  t.win_lines_above_cursor = t.cursor_win_line - 1
  if t.last_line_visible then
    t.lines_below_cursor = window.get_lines_below(vim.fn.line("."))
    t.win_bottom_line_eof = t.lines_below_cursor == t.win_lines_below_cursor
  else
    t.lines_below_cursor = t.win_lines_below_cursor
    t.win_bottom_line_eof = false
  end
  return t
end

--- _get_data wrapper
---@param winid integer
---@return Data
function window.get_data(winid)
  if winid == 0 then
    return get_data()
  else
    return vim.api.nvim_win_call(winid, get_data)
  end
end

return window
