local config = require("neoscroll.config")
local window = require("neoscroll.window")
local logic = require("neoscroll.logic")
local Scroll = require("neoscroll.scroll")

local scrolls = {}

-- Highlight group to hide the cursor
local hl_callback = function()
  vim.api.nvim_set_hl(0, "NeoscrollHiddenCursor", { reverse = true, blend = 100 })
end
hl_callback()
vim.api.nvim_create_autocmd({ "ColorScheme" }, { pattern = { "*" }, callback = hl_callback })

-- Helper function to check if a number is a float
local function is_float(n)
  return math.floor(math.abs(n)) ~= math.abs(n)
end

-- Transforms fraction of window to number of lines
local function get_lines_from_win_fraction(fraction, winid)
  local height_fraction = fraction * vim.api.nvim_win_get_height(winid)
  local lines
  if height_fraction < 0 then
    lines = -math.floor(math.abs(height_fraction) + 0.5)
  else
    lines = math.floor(height_fraction + 0.5)
  end
  if lines == 0 then
    return fraction < 0 and -1 or 1
  end
  return lines
end

local function stop_scrolling(scroll)
  scroll:tear_down()
  scrolls[scroll.opts.winid] = nil
end

local function make_scroll_callback(lines, time, scroll)
  local winid = scroll.opts.winid
  local move_cursor = scroll.opts.move_cursor
  local ef_name = scroll.opts.easing_name and scroll.opts.easing_name or config.easing_function
  local ef = config.easing_functions[ef_name]
  return function()
    local lines_to_scroll = scroll:lines_to_scroll()
    if lines_to_scroll == 0 then
      stop_scrolling(scroll)
      return
    end
    local data = winid == 0 and window.get_data() or vim.api.nvim_win_call(winid, window.get_data)
    local window_scrolls, cursor_scrolls = logic.who_scrolls(data, move_cursor, lines_to_scroll)
    if not window_scrolls and not cursor_scrolls then
      stop_scrolling(scroll)
      return
    end

    if math.abs(lines_to_scroll) > 2 and ef then
      local next_lines_to_scroll = math.abs(lines_to_scroll) - 2
      local next_time_step = logic.compute_time_step(next_lines_to_scroll, lines, time, ef)
      -- sets the repeat of the next cycle
      scroll.scroll_timer:set_repeat(next_time_step)
    end
    if math.abs(lines_to_scroll) == 0 then
      stop_scrolling(scroll)
      return
    end
    local success = scroll:scroll_one_line(lines_to_scroll, window_scrolls, cursor_scrolls)
    local new_lines_to_scroll = scroll:lines_to_scroll()
    if new_lines_to_scroll == 0 or not success then
      stop_scrolling(scroll)
      return
    end
  end
end

local neoscroll = {}

---Scrolling function
---@param lines number Number of lines to scroll or fraction of window to scroll
---@param move_cursor boolean Scroll the window and the cursor simultaneously
---@param time number Duration of the animation in miliseconds
---@param easing_name string Easing function to smooth the animation
---@param info table
---@param winid integer ID of the window to scroll
function neoscroll.scroll(lines, move_cursor, time, easing_name, info, winid)
  winid = winid or 0
  local scroll_opts = {
    move_cursor = move_cursor,
    easing_name = easing_name,
    info = info,
    winid = winid,
  }
  -- If lines is a fraction of the window transform it to lines
  if is_float(lines) then
    lines = get_lines_from_win_fraction(lines, scroll_opts.winid)
  end
  if lines == 0 then
    return
  end
  if scrolls[winid] == nil then
    scrolls[winid] = Scroll:new(scroll_opts)
  end
  local scroll = scrolls[winid]
  -- If still scrolling just modify the amount of lines to scroll
  -- If the scroll is in the opposite direction and
  -- lines_to_scroll is longer than lines stop smoothly
  if scroll.scrolling then
    local lines_to_scroll = scroll:lines_to_scroll()
    local opposite_direction = lines_to_scroll * lines < 0
    local long_scroll = math.abs(lines_to_scroll) - math.abs(lines) > 0
    if opposite_direction and long_scroll then
      scroll.target_line = scroll.relative_line - lines
    elseif scroll.continuous_scroll then
      scroll.target_line = scroll.relative_line + 2 * lines
    elseif math.abs(lines_to_scroll) > math.abs(5 * lines) then
      scroll.continuous_scroll = true
      scroll.relative_line = scroll.target_line - 2 * lines
    else
      scroll.target_line = scroll.target_line + lines
    end
    return
  end
  -- cursor_win_line is used in scroll:scroll_one_line() to check that the cursor remains
  -- in the same window line and we correct for it on the fly if required
  -- This is only relevant when both window_scrolls and cursor_scrolls are true
  local data = winid == 0 and window.get_data() or vim.api.nvim_win_call(winid, window.get_data)
  local half_window = math.floor(data.window_height / 2)
  if data.scrolloff >= half_window then
    scroll.initial_cursor_win_line = half_window
  elseif data.win_lines_above_cursor <= data.scrolloff then
    scroll.initial_cursor_win_line = data.scrolloff + 1
  elseif data.win_lines_below_cursor <= data.scrolloff then
    scroll.initial_cursor_win_line = data.window_height - data.scrolloff
  else
    scroll.initial_cursor_win_line = data.cursor_win_line
  end
  -- Check if the window and the cursor are allowed to scroll in that direction
  local window_scrolls, cursor_scrolls = logic.who_scrolls(data, move_cursor, lines)
  -- If neither the window nor the cursor are allowed to scroll finish early
  if not window_scrolls and not cursor_scrolls then
    return
  end
  -- Preparation before scrolling starts
  scroll:set_up(lines, move_cursor, info, winid)
  -- If easing function is not specified default to easing_function
  local ef_name = easing_name and easing_name or config.easing_function
  local ef = config.easing_functions[ef_name]

  local lines_to_scroll_abs = math.abs(scroll:lines_to_scroll())
  local success = scroll:scroll_one_line(lines, window_scrolls, cursor_scrolls)
  local new_lines_to_scroll = scroll.target_line - scroll.relative_line
  if new_lines_to_scroll == 0 or not success then
    stop_scrolling(scroll)
    return
  end
  local time_step = logic.compute_time_step(lines_to_scroll_abs, lines, time, ef)
  local next_time_step = logic.compute_time_step(lines_to_scroll_abs - 1, lines, time, ef)
  local next_next_time_step = logic.compute_time_step(lines_to_scroll_abs - 2, lines, time, ef)

  -- Callback function triggered by scroll_timer
  local scroll_callback = make_scroll_callback(lines, time, scroll)
  -- Start timer to scroll the rest of the lines
  scroll.scroll_timer:start(time_step, next_time_step, vim.schedule_wrap(scroll_callback))
  scroll.scroll_timer:set_repeat(next_next_time_step)
end

---Wrapper for zt
---@param half_screen_time number Duration of the animation for a scroll of half a window
---@param easing_name string Easing function to smooth the animation
---@param info table
function neoscroll.zt(half_screen_time, easing_name, info, winid)
  local window_height = vim.fn.winheight(0)
  local win_lines_above_cursor = vim.fn.winline() - 1
  -- Temporary fix for garbage values in local scrolloff when not set
  local lines = win_lines_above_cursor - window.scrolloff()
  if lines == 0 then
    return
  end
  local corrected_time =
    math.floor(half_screen_time * (math.abs(lines) / (window_height / 2)) + 0.5)
  neoscroll.scroll(lines, false, corrected_time, easing_name, info, winid)
end
-- Wrapper for zz
---@param half_screen_time number Duration of the animation for a scroll of half a window
---@param easing_name string Easing function to smooth the animation
---@param info table
function neoscroll.zz(half_screen_time, easing_name, info, winid)
  local window_height = vim.fn.winheight(0)
  local lines = vim.fn.winline() - math.ceil(window_height / 2)
  if lines == 0 then
    return
  end
  local corrected_time =
    math.floor(half_screen_time * (math.abs(lines) / (window_height / 2)) + 0.5)
  neoscroll.scroll(lines, false, corrected_time, easing_name, info, winid)
end
-- Wrapper for zb
---@param half_screen_time number Duration of the animation for a scroll of half a window
---@param easing_name string Easing function to smooth the animation
---@param info table
function neoscroll.zb(half_screen_time, easing_name, info, winid)
  local window_height = vim.fn.winheight(0)
  local lines_below_cursor = window_height - vim.fn.winline()
  -- Temporary fix for garbage values in local scrolloff when not set
  local lines = -lines_below_cursor + window.scrolloff()
  if lines == 0 then
    return
  end
  local corrected_time =
    math.floor(half_screen_time * (math.abs(lines) / (window_height / 2)) + 0.5)
  neoscroll.scroll(lines, false, corrected_time, easing_name, info, winid)
end

---Emulates `G` motion
---@param half_screen_time number Duration of the animation for a scroll of half a window
---@param easing_name string Easing function to smooth the animation
---@param info table
function neoscroll.G(half_screen_time, easing_name, info, winid)
  local lines = window.get_lines_below(vim.fn.line("w$"))
  local window_height = vim.fn.winheight(0)
  local corrected_time =
    math.floor(half_screen_time * (math.abs(lines) / (window_height / 2)) + 0.5)
  info.G = true
  neoscroll.scroll(lines, true, corrected_time, easing_name, info, winid)
end

-- ---Emulates `gg` motion
-- ---@param half_screen_time number Duration of the animation for a scroll of half a window
-- ---@param easing_name string Easing function to smooth the animation
-- ---@param info table
function neoscroll.gg(half_screen_time, easing_name, info, winid)
  local lines = window.get_lines_above(vim.fn.line("w0"))
  local window_height = vim.fn.winheight(winid)
  local cursor_win_line = vim.fn.winline()
  lines = -lines - cursor_win_line
  local corrected_time =
    math.floor(half_screen_time * (math.abs(lines) / (window_height / 2)) + 0.5)
  neoscroll.scroll(lines, true, corrected_time, easing_name, info, winid)
end

function neoscroll.setup(custom_opts)
  config.set_options(custom_opts)
  config.set_mappings()
  vim.cmd("command! NeoscrollEnablePM let b:neoscroll_performance_mode = v:true")
  vim.cmd("command! NeoscrollDisablePM let b:neoscroll_performance_mode = v:false")
  vim.cmd("command! NeoscrollEnableBufferPM let b:neoscroll_performance_mode = v:true")
  vim.cmd("command! NeoscrollDisableBufferPM let b:neoscroll_performance_mode = v:false")
  vim.cmd("command! NeoscrollEnableGlobalPM let g:neoscroll_performance_mode = v:true")
  vim.cmd("command! NeoscrollDisablGlobalePM let g:neoscroll_performance_mode = v:false")
  if config.performance_mode then
    vim.g.neoscroll_performance_mode = true
  end
end

return neoscroll
