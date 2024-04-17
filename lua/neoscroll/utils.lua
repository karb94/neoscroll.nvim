local utils = {}

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


-- Helper function to check if a number is a float
function utils.is_float(n)
	return math.floor(math.abs(n)) ~= math.abs(n)
end

function utils.get_lines_above(line)
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
function utils.get_lines_below(line)
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

-- Collect all the necessary window, buffer and cursor data
-- vim.fn.line("w0") -> if there's a fold returns first line of fold
-- vim.fn.line("w$") -> if there's a fold returns last line of fold
---@return Data
function utils.get_data()
	local data = {}
	data.win_top_line = vim.fn.line("w0")
	data.win_bottom_line = vim.fn.line("w$")
	data.last_line = vim.fn.line("$")
	data.first_line_visible = data.win_top_line == 1
	data.last_line_visible = data.win_bottom_line == data.last_line
	data.window_height = vim.fn.winheight(0)
	data.cursor_win_line = vim.fn.winline()
	data.win_lines_below_cursor = data.window_height - data.cursor_win_line
	data.win_lines_above_cursor = data.cursor_win_line - 1
  if data.last_line_visible then
    data.lines_below_cursor = utils.get_lines_below(vim.fn.line("."))
    data.win_bottom_line_eof = data.lines_below_cursor == data.win_lines_below_cursor
  else
    data.lines_below_cursor = data.win_lines_below_cursor
    data.win_bottom_line_eof = false
  end
	return data
end

-- Hide/unhide cursor during scrolling for a better visual effect
function utils.hide_cursor()
	if vim.o.termguicolors and vim.o.guicursor ~= "" then
		utils.guicursor = vim.o.guicursor
		vim.o.guicursor = "a:NeoscrollHiddenCursor"
	end
end
function utils.unhide_cursor()
	if vim.o.guicursor == "a:NeoscrollHiddenCursor" then
		vim.o.guicursor = utils.guicursor
	end
end

-- Transforms fraction of window to number of lines
function utils.get_lines_from_win_fraction(fraction)
	local height_fraction = fraction * vim.api.nvim_win_get_height(0)
	local lines
	if height_fraction < 0 then
		lines = -math.floor(math.abs(height_fraction) + 0.5)
	else
		lines = math.floor(height_fraction + 0.5)
	end
	return lines
end

function utils.get_scrolloff()
  local window_scrolloff = vim.wo.scrolloff
  if window_scrolloff == -1 then
    return vim.go.scrolloff
  else
    return window_scrolloff
  end
end

return utils
