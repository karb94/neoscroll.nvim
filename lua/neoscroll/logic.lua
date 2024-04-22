local config = require('neoscroll.config')

local logic = {}

---Window rules for when to stop scrolling
---@param data Data
---@param move_cursor any
---@param direction any
---@return boolean
local function window_reached_limit(data, move_cursor, direction)
  if data.last_line_visible and direction > 0 then
    if move_cursor then
      if config.stop_eof and data.last_line_visible then
        return true
      elseif config.respect_scrolloff and data.lines_below_cursor <= data.scrolloff then
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
    if config.respect_scrolloff and data.win_lines_above_cursor <= data.scrolloff then
      return true
    end
    return data.win_lines_above_cursor == 0
  elseif data.last_line_visible then
    if config.respect_scrolloff and data.lines_below_cursor <= data.scrolloff then
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
  local scrolloff = data.scrolloff
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
function logic.who_scrolls(data, move_cursor, direction)
  if direction == 0 then
    error("Direction cannot be zero")
  end
  local window_scrolls
  window_scrolls = not window_reached_limit(data, move_cursor, direction)
  if not move_cursor then
    return window_scrolls, false
  elseif window_scrolls then
    return true, not cursor_in_scrolloff(data, direction)
  elseif config.cursor_scrolls_alone then
    return false, not cursor_reached_limit(data, direction)
  else
    return false, false
  end
end

---Compute current time step of animation
---@param lines_to_scroll integer Number of lines left to scroll
---@param lines integer Initial number of lines to scroll
---@param time number Total time of the animation
---@param easing fun(x: number): number Easing function to smooth the animation
---@return integer
function logic.compute_time_step(lines_to_scroll, lines, time, easing)
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

return logic
