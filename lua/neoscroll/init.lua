local config = require("neoscroll.config")
local utils = require("neoscroll.utils")
local opts

local ctrl_y = vim.api.nvim_replace_termcodes("<C-y>", false, false, true)
local ctrl_e = vim.api.nvim_replace_termcodes("<C-e>", false, false, true)
local active_scroll = {
  winid = 0,
  target_line = 0,
  relative_line = 0,
  initial_cursor_win_line = nil,
  scrolling = false,
  continuous_scroll = false,
  scroll_timer = vim.loop.new_timer()
}

-- Highlight group to hide the cursor
local hl_callback = function()
  vim.api.nvim_set_hl(0, "NeoscrollHiddenCursor", { reverse = true, blend = 100 })
end
hl_callback()
vim.api.nvim_create_autocmd({ "ColorScheme" }, { pattern = { "*" }, callback = hl_callback })

---Window rules for when to stop scrolling
---@param data Data
---@param move_cursor any
---@param direction any
---@return boolean
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

---Cursor rules for when to stop scrolling
---@param data Data
---@param direction integer
---@return boolean
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
  else
    return false
  end
end

---Checks if the cursor would be forced to move due to it being within scrolloff
---@param data Data
---@param direction any
---@return boolean cursor_in_scrolloff
local function cursor_in_scrolloff(data, direction)
  local scrolloff = utils.get_scrolloff()
  if direction < 0 then
    if data.last_line_visible then
      return data.win_bottom_line_eof and data.win_lines_below_cursor <= scrolloff
    else
      return data.win_lines_below_cursor <= scrolloff
    end
  else
    return data.win_lines_above_cursor <= scrolloff
  end
end

---Check if the window and the cursor can be scrolled further
---@param data Data
---@param move_cursor boolean
---@param direction integer
---@return boolean window_scrolls Window is allowed to scroll
---@return boolean cursor_scrolls Cursor is allowed to scroll
local function who_scrolls(data, move_cursor, direction)
  if direction == 0 then
    error("Direction cannot be zero")
  end
  local window_scrolls
  window_scrolls = not window_reached_limit(data, move_cursor, direction)
  if not move_cursor then
    return window_scrolls, false
  elseif window_scrolls then
    return true, not cursor_in_scrolloff(data, direction)
  elseif opts.cursor_scrolls_alone then
    return false, not cursor_reached_limit(data, direction)
  else
    return false, false
  end
end

---Scroll one line in the given direction
---@param lines_to_scroll integer
---@param scroll_window boolean
---@param scroll_cursor boolean
---@return boolean
local function scroll_one_line(lines_to_scroll, scroll_window, scroll_cursor)
  local winline_before = vim.fn.winline()
  local initial_cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local cursor_scroll_cmd = lines_to_scroll > 0 and "gj" or "gk"
  local cursor_scroll_args = scroll_cursor and cursor_scroll_cmd or ""
  local window_scroll_cmd = lines_to_scroll > 0 and ctrl_e or ctrl_y
  local window_scroll_args = scroll_window and window_scroll_cmd or ""
  local args = window_scroll_args .. cursor_scroll_args
  local sucess, _ = pcall(vim.cmd.normal, { bang = true, args = { args } }) ---@diagnostic disable-line
  if not sucess then
    return false
  end
  local scrolled_lines = lines_to_scroll > 0 and 1 or -1
  -- Correct for wrapped lines
  local lines_behind = vim.fn.winline() - active_scroll.initial_cursor_win_line
  if lines_to_scroll > 0 then
    lines_behind = -lines_behind
  end
  if scroll_cursor and scroll_window and lines_behind > 0 then
    local cursor_args = string.rep(cursor_scroll_cmd, lines_behind)
    local sucess, _ = pcall(vim.cmd.normal, { bang = true, args = { cursor_args } }) ---@diagnostic disable-line
    if not sucess then
      return false
    end
  end
  -- If the cursor is still on the same line we can use the change in window line
  -- to calculate the lines we have scrolled more accurately (not affected by wrapped lines)
  if initial_cursor_line == vim.api.nvim_win_get_cursor(0)[1] then
    scrolled_lines = winline_before - vim.fn.winline()
  end
  -- If we have past our target line (e.g. when forced by  wrapped lines) set lines_to_scroll
  -- to 1 to trigger stop_scrolling(). Otherwise it will start scrolling backwards and
  -- potentially run into an infinite loop
  local new_relative_line = active_scroll.relative_line + scrolled_lines
  local new_lines_to_scroll = active_scroll.target_line - new_relative_line
  local target_overshot = lines_to_scroll * new_lines_to_scroll < 0
  if target_overshot then
    active_scroll.relative_line = active_scroll.target_line
  else
    active_scroll.relative_line = active_scroll.relative_line + scrolled_lines
  end
  return true
end

---Scrolling constructor
---@param lines integer
---@param move_cursor boolean
---@param info table
local function before_scrolling(lines, move_cursor, info)
  if opts.pre_hook ~= nil then
    opts.pre_hook(info)
  end
  -- Start scrolling
  active_scroll.scrolling = true
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
  active_scroll.target_line = lines
end

---Scrolling destructor
---@param move_cursor boolean
---@param info table
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

  active_scroll.relative_line = 0
  active_scroll.target_line = 0
  active_scroll.scroll_timer:stop()
  active_scroll.scrolling = false
  active_scroll.continuous_scroll = false
end

---Compute current time step of animation
---@param lines_to_scroll integer Number of lines left to scroll
---@param lines integer Initial number of lines to scroll
---@param time number Total time of the animation
---@param easing fun(x: number): number Easing function to smooth the animation
---@return integer
local function compute_time_step(lines_to_scroll, lines, time, easing)
  -- lines_to_scroll should always be positive
  -- If there's less than one line to scroll time_step doesn't matter
  if lines_to_scroll < 1 then
    return 1000
  end
  local lines_range = math.abs(lines)
  local time_step
  -- If not yet in range return average time-step
  if not easing then
    time_step = math.floor(time / (lines_range - 1) + 0.5)
  elseif lines_to_scroll >= lines_range then
    time_step = math.floor(time * easing(1 / lines_range) + 0.5)
  else
    local x1 = (lines_range - lines_to_scroll) / lines_range
    local x2 = (lines_range - lines_to_scroll + 1) / lines_range
    time_step = math.floor(time * (easing(x2) - easing(x1)) + 0.5)
  end
  if time_step == 0 then
    time_step = 1
  end
  return time_step
end

local neoscroll = {}

---Scrolling function
---@param lines number Number of lines to scroll or fraction of window to scroll
---@param move_cursor boolean Scroll the window and the cursor simultaneously
---@param time number Duration of the animation in miliseconds
---@param easing_name string Easing function to smooth the animation
---@param info table
function neoscroll.scroll(lines, move_cursor, time, easing_name, info)
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
  if active_scroll.scrolling  then
    local lines_to_scroll = active_scroll.relative_line - active_scroll.target_line
    local opposite_direction = lines_to_scroll * lines > 0
    local long_scroll = math.abs(lines_to_scroll) - math.abs(lines) > 0
    if opposite_direction and long_scroll then
      active_scroll.target_line = active_scroll.relative_line - lines
    elseif active_scroll.continuous_scroll then
      active_scroll.target_line = active_scroll.relative_line + 2 * lines
    elseif math.abs(lines_to_scroll) > math.abs(5 * lines) then
      active_scroll.continuous_scroll = true
      active_scroll.relative_line = active_scroll.target_line - 2 * lines
    else
      active_scroll.target_line = active_scroll.target_line + lines
    end

    return
  end
  -- cursor_win_line is used in scroll_one_line() to check that the cursor remains
  -- in the same window line and we correct for it on the fly if required
  -- This is only relevant when both window_scrolls and cursor_scrolls are true
  local data = utils.get_data()
  local half_window = math.floor(data.window_height / 2)
  if utils.get_scrolloff() >= half_window then
    active_scroll.initial_cursor_win_line = half_window
  elseif data.win_lines_above_cursor <= utils.get_scrolloff() then
    active_scroll.initial_cursor_win_line = utils.get_scrolloff() + 1
  elseif data.win_lines_below_cursor <= utils.get_scrolloff() then
    active_scroll.initial_cursor_win_line = data.window_height - utils.get_scrolloff()
  else
    active_scroll.initial_cursor_win_line = data.cursor_win_line
  end
  -- Check if the window and the cursor are allowed to scroll in that direction
  local window_scrolls, cursor_scrolls = who_scrolls(data, move_cursor, lines)
  -- If neither the window nor the cursor are allowed to scroll finish early
  if not window_scrolls and not cursor_scrolls then
    return
  end
  -- Preparation before scrolling starts
  before_scrolling(lines, move_cursor, info)
  -- If easing function is not specified default to easing_function
  local ef_name = easing_name and easing_name or opts.easing_function
  local ef = config.easing_functions[ef_name]

  local lines_to_scroll = math.abs(active_scroll.relative_line - active_scroll.target_line)
  local success = scroll_one_line(lines, window_scrolls, cursor_scrolls)
  if lines_to_scroll == 1 or not success then
    stop_scrolling(move_cursor, info)
    return
  end
  local time_step = compute_time_step(lines_to_scroll, lines, time, ef)
  local next_time_step = compute_time_step(lines_to_scroll - 1, lines, time, ef)
  local next_next_time_step = compute_time_step(lines_to_scroll - 2, lines, time, ef)
  -- Scroll the first line

  -- Callback function triggered by scroll_timer
  local function scroll_callback()
    lines_to_scroll = active_scroll.target_line - active_scroll.relative_line
    data = utils.get_data()
    window_scrolls, cursor_scrolls = who_scrolls(data, move_cursor, lines_to_scroll)
    if not window_scrolls and not cursor_scrolls then
      stop_scrolling(move_cursor, info)
      return
    end

    if math.abs(lines_to_scroll) > 2 and ef then
      local next_lines_to_scroll = math.abs(lines_to_scroll) - 2
      next_time_step = compute_time_step(next_lines_to_scroll, lines, time, ef)
      -- sets the repeat of the next cycle
      active_scroll.scroll_timer:set_repeat(next_time_step)
    end
    if math.abs(lines_to_scroll) == 0 then
      stop_scrolling(move_cursor, info)
      return
    end
    success = scroll_one_line(lines_to_scroll, window_scrolls, cursor_scrolls)
    lines_to_scroll = active_scroll.target_line - active_scroll.relative_line
    if math.abs(lines_to_scroll) == 0 or not success then
      stop_scrolling(move_cursor, info)
      return
    end
  end

  -- Start timer to scroll the rest of the lines
  active_scroll.scroll_timer:start(time_step, next_time_step, vim.schedule_wrap(scroll_callback))
  active_scroll.scroll_timer:set_repeat(next_next_time_step)
end

---Wrapper for zt
---@param half_screen_time number Duration of the animation for a scroll of half a window
---@param easing_name string Easing function to smooth the animation
---@param info table
function neoscroll.zt(half_screen_time, easing_name, info)
  local window_height = vim.fn.winheight(0)
  local win_lines_above_cursor = vim.fn.winline() - 1
  -- Temporary fix for garbage values in local scrolloff when not set
  local lines = win_lines_above_cursor - utils.get_scrolloff()
  if lines == 0 then
    return
  end
  local corrected_time =
    math.floor(half_screen_time * (math.abs(lines) / (window_height / 2)) + 0.5)
  neoscroll.scroll(lines, false, corrected_time, easing_name, info)
end
-- Wrapper for zz
---@param half_screen_time number Duration of the animation for a scroll of half a window
---@param easing_name string Easing function to smooth the animation
---@param info table
function neoscroll.zz(half_screen_time, easing_name, info)
  local window_height = vim.fn.winheight(0)
  local lines = vim.fn.winline() - math.ceil(window_height / 2)
  if lines == 0 then
    return
  end
  local corrected_time =
    math.floor(half_screen_time * (math.abs(lines) / (window_height / 2)) + 0.5)
  neoscroll.scroll(lines, false, corrected_time, easing_name, info)
end
-- Wrapper for zb
---@param half_screen_time number Duration of the animation for a scroll of half a window
---@param easing_name string Easing function to smooth the animation
---@param info table
function neoscroll.zb(half_screen_time, easing_name, info)
  local window_height = vim.fn.winheight(0)
  local lines_below_cursor = window_height - vim.fn.winline()
  -- Temporary fix for garbage values in local scrolloff when not set
  local lines = -lines_below_cursor + utils.get_scrolloff()
  if lines == 0 then
    return
  end
  local corrected_time =
    math.floor(half_screen_time * (math.abs(lines) / (window_height / 2)) + 0.5)
  neoscroll.scroll(lines, false, corrected_time, easing_name, info)
end

---Emulates `G` motion
---@param half_screen_time number Duration of the animation for a scroll of half a window
---@param easing_name string Easing function to smooth the animation
---@param info table
function neoscroll.G(half_screen_time, easing_name, info)
  local lines = utils.get_lines_below(vim.fn.line("w$"))
  local window_height = vim.fn.winheight(0)
  local cursor_win_line = vim.fn.winline()
  local corrected_time =
    math.floor(half_screen_time * (math.abs(lines) / (window_height / 2)) + 0.5)
  info.G = true
  neoscroll.scroll(lines, true, corrected_time, easing_name, info)
end

---Emulates `gg` motion
---@param half_screen_time number Duration of the animation for a scroll of half a window
---@param easing_name string Easing function to smooth the animation
---@param info table
function neoscroll.gg(half_screen_time, easing_name, info)
  local lines = utils.get_lines_above(vim.fn.line("w0"))
  local window_height = vim.fn.winheight(0)
  local cursor_win_line = vim.fn.winline()
  lines = -lines - active_scroll.initial_cursor_win_line
  local corrected_time =
    math.floor(half_screen_time * (math.abs(lines) / (window_height / 2)) + 0.5)
  neoscroll.scroll(lines, true, corrected_time, easing_name, info)
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
