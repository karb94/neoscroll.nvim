local config = require('neoscroll.config')
local ctrl_y = vim.api.nvim_replace_termcodes("<C-y>", false, false, true)
local ctrl_e = vim.api.nvim_replace_termcodes("<C-e>", false, false, true)

local function create_scroll_func(scroll_args, winid)
  local scroll_func = function()
    vim.cmd.normal({ bang = true, args = { scroll_args } })
  end
  -- Avoid vim.api.nvim_win_call if we don't need it
  if winid ==  0 then
    return scroll_func
  else
    return function()
      vim.api.nvim_win_call(winid, scroll_func)
    end
  end
end

local Scroll = {
  target_line = 0,
  relative_line = 0,
  initial_cursor_win_line = nil,
  scrolling = false,
  continuous_scroll = false,
  scroll_timer = vim.loop.new_timer(),
}

function Scroll:new(opts)
  local o = {opts = opts}
  setmetatable(o, self)
  self.__index = self
  return o
end

function Scroll:lines_to_scroll()
  return self.target_line - self.relative_line
end

-- Hide/unhide cursor during scrolling for a better visual effect
function Scroll:hide_cursor()
  if vim.o.termguicolors and vim.o.guicursor ~= "" then
    self.guicursor = vim.o.guicursor
    vim.o.guicursor = "a:NeoscrollHiddenCursor"
  end
end

function Scroll:unhide_cursor()
  if vim.o.guicursor == "a:NeoscrollHiddenCursor" then
    vim.o.guicursor = self.guicursor
  end
end

---Scrolling constructor
---@param lines integer
---@param move_cursor boolean
---@param info table
function Scroll:set_up(lines, move_cursor, info)
  if config.pre_hook ~= nil then
    config.pre_hook(info)
  end
  -- Start scrolling
  self.scrolling = true
  -- Hide cursor line
  if config.hide_cursor and move_cursor then
    self:hide_cursor()
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
  self.target_line = lines
end

---Scrolling destructor
function Scroll:tear_down()
  self.scroll_timer:stop()

  if config.hide_cursor == true and self.opts.move_cursor then
    self:unhide_cursor()
  end
  --Performance mode
  local performance_mode = vim.b.neoscroll_performance_mode or vim.g.neoscroll_performance_mode
  if performance_mode and self.opts.move_cursor then
    vim.bo.syntax = "ON"
    if vim.g.loaded_nvim_treesitter then
      vim.cmd("TSBufEnable highlight")
    end
  end
  if config.post_hook ~= nil then
    config.post_hook(self.opts.info)
  end

  self.relative_line = 0
  self.target_line = 0
  self.scrolling = false
  self.continuous_scroll = false
end

---Scroll one line in the given direction
---@param lines_to_scroll integer
---@param scroll_window boolean
---@param scroll_cursor boolean
---@return boolean
function Scroll:scroll_one_line(lines_to_scroll, scroll_window, scroll_cursor)
  if lines_to_scroll == 0 then
    error("lines_to_scroll cannot be zero")
  end
  local winline_before = vim.fn.winline()
  local initial_cursor_line = vim.api.nvim_win_get_cursor(self.opts.winid)[1]
  local cursor_scroll_cmd = lines_to_scroll > 0 and "gj" or "gk"
  local cursor_scroll_args = scroll_cursor and cursor_scroll_cmd or ""
  local window_scroll_cmd = lines_to_scroll > 0 and ctrl_e or ctrl_y
  local window_scroll_args = scroll_window and window_scroll_cmd or ""
  local scroll_args = window_scroll_args .. cursor_scroll_args
  local success, _ = pcall(create_scroll_func(scroll_args, self.opts.winid)) ---@diagnostic disable-line
  if not success then
    return false
  end
  local scrolled_lines = lines_to_scroll > 0 and 1 or -1
  -- Correct for wrapped lines
  local lines_behind = vim.fn.winline() - self.initial_cursor_win_line
  if lines_to_scroll > 0 then
    lines_behind = -lines_behind
  end
  if scroll_cursor and scroll_window and lines_behind > 0 then
    local cursor_args = string.rep(cursor_scroll_cmd, lines_behind)
    local success, _ = pcall(create_scroll_func(cursor_args, self.opts.winid)) ---@diagnostic disable-line
    if not success then
      return false
    end
  end
  -- If the cursor is still on the same line we can use the change in window line
  -- to calculate the lines we have scrolled more accurately (not affected by wrapped lines)
  if initial_cursor_line == vim.api.nvim_win_get_cursor(self.opts.winid)[1] then
    scrolled_lines = winline_before - vim.fn.winline()
  end
  -- If we have past our target line (e.g. when forced by  wrapped lines) set lines_to_scroll
  -- to 1 to trigger Scroll:tear_down(). Otherwise it will start scrolling backwards and
  -- potentially run into an infinite loop
  local new_relative_line = self.relative_line + scrolled_lines
  local new_lines_to_scroll = self.target_line - new_relative_line
  local target_overshot = lines_to_scroll * new_lines_to_scroll < 0
  if target_overshot then
    self.relative_line = self.target_line
  else
    self.relative_line = self.relative_line + scrolled_lines
  end
  return true
end

return Scroll
