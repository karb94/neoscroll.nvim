local config = require("neoscroll.config").opts
local ctrl_y = vim.api.nvim_replace_termcodes("<C-y>", false, false, true)
local ctrl_e = vim.api.nvim_replace_termcodes("<C-e>", false, false, true)

-- stylua: ignore start
local easing_function = {
  quadratic = function(x) return 1 - math.pow(1 - x, 1 / 2) end,
  cubic = function(x) return 1 - math.pow(1 - x, 1 / 3) end,
  quartic = function(x) return 1 - math.pow(1 - x, 1 / 4) end,
  quintic = function(x) return 1 - math.pow(1 - x, 1 / 5) end,
  circular = function(x) return 1 - math.pow(1 - x * x, 1 / 2) end,
  sine = function(x) return 2 * math.asin(x) / math.pi end,
}
-- stylua: ignore end

local function create_scroll_func(scroll_args, winid)
  local scroll_func = function()
    vim.cmd.normal({ bang = true, args = { scroll_args } })
  end
  -- Avoid vim.api.nvim_win_call if we don't need it
  if winid == 0 then
    return scroll_func
  else
    return function()
      vim.api.nvim_win_call(winid, scroll_func)
    end
  end
end

local scroll = {
  target_line = 0,
  relative_line = 0,
  initial_cursor_win_line = nil,
  scrolling = false,
  continuous_scroll = false,
  timer = vim.loop.new_timer(),
}

function scroll:new(lines, opts)
  local o = { lines = lines, opts = opts }
  setmetatable(o, self)
  self.__index = self
  return o
end

function scroll:lines_to_scroll()
  return self.target_line - self.relative_line
end

-- Hide/unhide cursor during scrolling for a better visual effect
function scroll:hide_cursor()
  if vim.o.termguicolors and vim.o.guicursor ~= "" then
    self.guicursor = vim.o.guicursor
    vim.o.guicursor = "a:NeoscrollHiddenCursor"
  end
end

function scroll:unhide_cursor()
  if vim.o.guicursor == "a:NeoscrollHiddenCursor" then
    vim.o.guicursor = self.guicursor
  end
end

---scrolling constructor
function scroll:set_up()
  if config.pre_hook ~= nil then
    config.pre_hook(self.opts.info)
  end
  -- Start scrolling
  self.scrolling = true
  -- Hide cursor line
  if config.hide_cursor and self.opts.move_cursor then
    self:hide_cursor()
  end
  -- Disable events
  if next(config.ignored_events) ~= nil then
    vim.opt.eventignore:append(config.ignored_events)
  end
  -- Performance mode
  local performance_mode = vim.b.neoscroll_performance_mode or vim.g.neoscroll_performance_mode
  if performance_mode and self.opts.move_cursor then
    if vim.g.loaded_nvim_treesitter then
      vim.cmd("TSBufDisable highlight")
    end
    vim.bo.syntax = "OFF"
  end
  -- Assign number of lines to scroll
  self.target_line = self.lines
end

---scrolling destructor
function scroll:tear_down()
  self.timer:stop()

  -- Unhide cursor
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
  -- Reenable events
  if next(config.ignored_events) ~= nil then
    vim.opt.eventignore:remove(config.ignored_events)
  end

  self.relative_line = 0
  self.target_line = 0
  self.scrolling = false
  self.continuous_scroll = false
end

---Compute current time step of animation
---@param lines_to_scroll integer Number of lines left to scroll
---@return integer
function scroll:compute_time_step(lines_to_scroll)
  local easing = self.opts.easing or config.easing_function or config.easing
  local ef = easing_function[easing]
  -- lines_to_scroll should always be positive
  -- If there's less than one line to scroll time_step doesn't matter
  if lines_to_scroll < 1 then
    return 1000
  end
  local lines_range = math.abs(self.lines)
  local time_step
  -- If not yet in range return average time-step
  if not ef then
    time_step = math.floor(self.opts.duration / (lines_range - 1) + 0.5)
  elseif lines_to_scroll >= lines_range then
    time_step = math.floor(self.opts.duration * ef(1 / lines_range) + 0.5)
  else
    local x1 = (lines_range - lines_to_scroll) / lines_range
    local x2 = (lines_range - lines_to_scroll + 1) / lines_range
    time_step = math.floor(self.opts.duration * (ef(x2) - ef(x1)) + 0.5)
  end
  if time_step == 0 then
    time_step = 1
  end
  return time_step
end

---scroll one line in the given direction
---@param lines_to_scroll integer
---@param scroll_window boolean
---@param scroll_cursor boolean
---@return boolean
function scroll:scroll_one_line(lines_to_scroll, scroll_window, scroll_cursor)
  if lines_to_scroll == 0 then
    error("lines_to_scroll cannot be zero")
  end
  local initial_winline = vim.api.nvim_win_call(self.opts.winid, vim.fn.winline)
  local initial_cursor_line = vim.api.nvim_win_get_cursor(self.opts.winid)[1]
  local cursor_scroll_cmd = lines_to_scroll > 0 and "gj" or "gk"
  local cursor_scroll_args = scroll_cursor and cursor_scroll_cmd or ""
  local window_scroll_cmd = lines_to_scroll > 0 and ctrl_e or ctrl_y
  local window_scroll_args = scroll_window and window_scroll_cmd or ""
  local scroll_args = window_scroll_args .. cursor_scroll_args
  local one_line_scroll = create_scroll_func(scroll_args, self.opts.winid)
  local success, _ = pcall(one_line_scroll) ---@diagnostic disable-line
  if not success then
    return false
  end
  local scrolled_lines = lines_to_scroll > 0 and 1 or -1

  if scroll_cursor and scroll_window then
    -- Correct for wrapped lines
    local winline = vim.api.nvim_win_call(self.opts.winid, vim.fn.winline)
    local lines_behind = winline - self.initial_cursor_win_line
    if lines_to_scroll > 0 then
      lines_behind = -lines_behind
    end
    if lines_behind > 0 then
      local cursor_args = string.rep(cursor_scroll_cmd, lines_behind)
      local catchup_scroll = create_scroll_func(cursor_args, self.opts.winid)
      local success, _ = pcall(catchup_scroll) ---@diagnostic disable-line
      if not success then
        return false
      end
    end
  end

  -- If the cursor is still on the same line we can use the change in window line
  -- to calculate the lines we have scrolled more accurately (not affected by wrapped lines)
  local cursor_line = vim.api.nvim_win_get_cursor(self.opts.winid)[1]
  if cursor_line == initial_cursor_line  then
    local final_winline = vim.api.nvim_win_call(self.opts.winid, vim.fn.winline)
    scrolled_lines = initial_winline - final_winline
  end

  -- If we have past our target line (e.g. when forced by  wrapped lines) set lines_to_scroll
  -- to 1 to trigger scroll:tear_down(). Otherwise it will start scrolling backwards and
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

return scroll
