local config = require("neoscroll.config").opts
local window = require("neoscroll.window")
local logic = require("neoscroll.logic")
local scroll = require("neoscroll.scroll")


-- Highlight group to hide the cursor
local hl_callback = function()
  vim.api.nvim_set_hl(
    0,
    "NeoscrollHiddenCursor",
    { reverse = true, blend = 100 }
  )
end
hl_callback()
local cursor_group = vim.api.nvim_create_augroup("NeoscrollHiddenCursor", {})
vim.api.nvim_create_autocmd(
  { "ColorScheme" },
  { group = cursor_group, callback = hl_callback }
)

-- Stop scrolling when changing window focus
local teardown_group = vim.api.nvim_create_augroup("NeoscrollTearDown", {})
local teardown_callback = function()
  if scroll.scrolling then
    scroll:tear_down()
  end
end
vim.api.nvim_create_autocmd(
  { "WinLeave" },
  { group = teardown_group, callback = teardown_callback }
)

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

local function make_scroll_callback()
  return function()
    local lines_to_scroll = scroll:lines_to_scroll()
    if lines_to_scroll == 0 then
      scroll:tear_down()
      return
    end
    local data = window.get_data(scroll.opts.winid)
    local window_scrolls, cursor_scrolls =
      logic.who_scrolls(data, scroll.opts.move_cursor, lines_to_scroll)
    if not window_scrolls and not cursor_scrolls then
      scroll:tear_down()
      return
    end

    if math.abs(lines_to_scroll) > 2 then
      local next_lines_to_scroll = math.abs(lines_to_scroll) - 2
      local next_time_step = scroll:compute_time_step(next_lines_to_scroll)
      -- sets the repeat of the next cycle
      scroll.timer:set_repeat(next_time_step)
    end
    if math.abs(lines_to_scroll) == 0 then
      scroll:tear_down()
      return
    end
    local success = scroll:scroll_one_line(lines_to_scroll, window_scrolls, cursor_scrolls)
    local new_lines_to_scroll = scroll:lines_to_scroll()
    if new_lines_to_scroll == 0 or not success then
      scroll:tear_down()
      return
    end
  end
end

local neoscroll = {}
neoscroll.signature_warning = true

---@param lines number
---@param move_cursor boolean | nil | table Scroll the window and the cursor simultaneously
---@param duration number | nil Duration of the animation in milliseconds
---@param easing string | nil Easing function to smooth the animation
---@param info table | nil
---@param winid integer | nil ID of the window to scroll
function neoscroll.scroll(lines, move_cursor, duration, easing, info, winid)
  local opts
  if type(move_cursor) == "table" then
    opts = move_cursor
  else
    if neoscroll.signature_warning then
      local old_sig = "scroll(lines, move_cursor, time[, easing])"
      local new_sig = "scroll(lines, opts)"
      local warning_msg = "Neoscroll: the function signature " ..
        old_sig .. " is deprecated in favour of the new " ..
      new_sig .. " signature. Run `help neoscroll.scroll()` for more info"
      vim.notify(warning_msg, vim.log.levels.WARN, {title = 'Neoscroll'})
      neoscroll.signature_warning = false
    end
    opts = {
      move_cursor = move_cursor,
      duration = duration,
      easing = easing,
      info = info,
      winid = winid,
    }
  end
  neoscroll.new_scroll(lines, opts)
end

---@class ScrollOpts
---@field move_cursor boolean | nil Scroll the window and the cursor simultaneously
---@field duration number | nil Duration of the animation in milliseconds
---@field easing string | nil Easing function to smooth the animation
---@field info table | nil
---@field winid integer | nil ID of the window to scroll
default_scroll_opts = {
  move_cursor = true,
  time = nil,
  winid = 0,
}

---Scrolling function
---@param lines number Number of lines to scroll or fraction of window to scroll
---@param opts ScrollOpts Scroll options
function neoscroll.new_scroll(lines, opts)
  scroll.opts = vim.tbl_deep_extend("force", default_scroll_opts, opts or {})
  -- Modify animation duration globally
  scroll.opts.duration = config.duration_multiplier * scroll.opts.duration
  -- If lines is a fraction of the window transform it to lines
  if is_float(lines) then
    lines = get_lines_from_win_fraction(lines, scroll.opts.winid)
  end
  scroll.lines = lines
  if lines == 0 then
    return
  end
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
  local data = window.get_data(scroll.opts.winid)
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
  local window_scrolls, cursor_scrolls = logic.who_scrolls(data, scroll.opts.move_cursor, lines)
  -- If neither the window nor the cursor are allowed to scroll finish early
  if not window_scrolls and not cursor_scrolls then
    return
  end
  -- Preparation before scrolling starts
  scroll:set_up()

  local lines_to_scroll_abs = math.abs(scroll:lines_to_scroll())
  local success = scroll:scroll_one_line(lines, window_scrolls, cursor_scrolls)
  local new_lines_to_scroll = scroll.target_line - scroll.relative_line
  if new_lines_to_scroll == 0 or not success then
    scroll:tear_down()
    return
  end
  local time_step = scroll:compute_time_step(lines_to_scroll_abs)
  local next_time_step = scroll:compute_time_step(lines_to_scroll_abs - 1)
  local next_next_time_step = scroll:compute_time_step(lines_to_scroll_abs - 2)

  -- Callback function triggered by timer
  local scroll_callback = make_scroll_callback()
  -- Start timer to scroll the rest of the lines
  scroll.timer:start(time_step, next_time_step, vim.schedule_wrap(scroll_callback))
  scroll.timer:set_repeat(next_next_time_step)
end

---ctrl-u emulation
---@param opts ScrollOpts
function neoscroll.ctrl_u(opts)
  opts = vim.tbl_deep_extend("force", opts, { move_cursor = true })
  require("neoscroll").scroll(-vim.wo.scroll, opts)
end

---ctrl-d emulation
---@param opts ScrollOpts
function neoscroll.ctrl_d(opts)
  opts = vim.tbl_deep_extend("force", opts, { move_cursor = true })
  require("neoscroll").scroll(vim.wo.scroll, opts)
end

---ctrl-b emulation
---@param opts ScrollOpts
function neoscroll.ctrl_b(opts)
  opts = vim.tbl_deep_extend("force", opts, { move_cursor = true })
  require("neoscroll").scroll(-vim.fn.winheight(0), opts)
end

---ctrl-f emulation
---@param opts ScrollOpts
function neoscroll.ctrl_f(opts)
  opts = vim.tbl_deep_extend("force", opts, { move_cursor = true })
  require("neoscroll").scroll(vim.fn.winheight(0), opts)
end

---@class Zopts
---@field half_win_duration number Duration of the animation in milliseconds
---@field easing string | nil Easing function to smooth the animation
---@field info table | nil
---@field winid integer | nil ID of the window to scroll

neoscroll.zt_warning = true
---zt emulation
---@param half_win_duration number | Zopts Duration of the animation for a scroll of half a window
---@param easing string | nil Easing function to smooth the animation
---@param info table | nil
function neoscroll.zt(half_win_duration, easing, info, winid)
  if type(half_win_duration) == "table" then
    local zopts = half_win_duration
    half_win_duration = zopts.half_win_duration
    easing = zopts.easing
    winid = zopts.winid
    info = zopts.info
  elseif neoscroll.zt_warning then
    local old_sig = "zt(half_win_duration, easing, info, winid)"
    local new_sig = "zt(opts)"
    local warning_msg = "Neoscroll: the function signature " ..
    old_sig .. " is deprecated in favour of the new " ..
    new_sig .. " signature. Run `help neoscroll.zt()` for more info"
    vim.notify(warning_msg, vim.log.levels.WARN, {title = 'Neoscroll'})
    neoscroll.zt_warning = false
  end
  local window_height = vim.fn.winheight(0)
  local win_lines_above_cursor = vim.fn.winline() - 1
  -- Temporary fix for garbage values in local scrolloff when not set
  local lines = win_lines_above_cursor - window.scrolloff()
  if lines == 0 then
    return
  end
  local duration = math.floor(half_win_duration * (math.abs(lines) / (window_height / 2)) + 0.5)
  local opts = {
    move_cursor = false,
    duration = duration,
    easing_name = easing,
    winid = winid,
    info = info,
  }
  neoscroll.scroll(lines, opts)
end

neoscroll.zz_warning = true
---zz emulation
---@param half_win_duration number | Zopts Duration of the animation for a scroll of half a window
---@param easing string | nil Easing function to smooth the animation
---@param info table | nil
function neoscroll.zz(half_win_duration, easing, info, winid)
  if type(half_win_duration) == "table" then
    local zopts = half_win_duration
    half_win_duration = zopts.half_win_duration
    easing = zopts.easing
    winid = zopts.winid
    info = zopts.info
  elseif neoscroll.zz_warning then
    local old_sig = "zz(half_win_duration, easing, info, winid)"
    local new_sig = "zz(opts)"
    local warning_msg = "Neoscroll: the function signature " ..
    old_sig .. " is deprecated in favour of the new " ..
    new_sig .. " signature. Run `help neoscroll.zz()` for more info"
    vim.notify(warning_msg, vim.log.levels.WARN, {title = 'Neoscroll'})
    neoscroll.zz_warning = false
  end
  local window_height = vim.fn.winheight(0)
  local lines = vim.fn.winline() - math.ceil(window_height / 2)
  if lines == 0 then
    return
  end
  local duration = math.floor(half_win_duration * (math.abs(lines) / (window_height / 2)) + 0.5)
  local opts = {
    move_cursor = false,
    duration = duration,
    easing_name = easing,
    winid = winid,
    info = info,
  }
  neoscroll.scroll(lines, opts)
end

neoscroll.zb_warning = true
---zb emulation
---@param half_win_duration number | Zopts Duration of the animation for a scroll of half a window
---@param easing string | nil Easing function to smooth the animation
---@param info table | nil
function neoscroll.zb(half_win_duration, easing, info, winid)
  if type(half_win_duration) == "table" then
    local zopts = half_win_duration
    half_win_duration = zopts.half_win_duration
    easing = zopts.easing
    winid = zopts.winid
    info = zopts.info
  elseif neoscroll.zb_warning then
    local old_sig = "zb(half_win_duration, easing, info, winid)"
    local new_sig = "zb(opts)"
    local warning_msg = "Neoscroll: the function signature " ..
    old_sig .. " is deprecated in favour of the new " ..
    new_sig .. " signature. Run `help neoscroll.zb()` for more info"
    vim.notify(warning_msg, vim.log.levels.WARN, {title = 'Neoscroll'})
    neoscroll.zb_warning = false
  end
  local window_height = vim.fn.winheight(0)
  local lines_below_cursor = window_height - vim.fn.winline()
  -- Temporary fix for garbage values in local scrolloff when not set
  local lines = -lines_below_cursor + window.scrolloff()
  if lines == 0 then
    return
  end
  local duration = math.floor(half_win_duration * (math.abs(lines) / (window_height / 2)) + 0.5)
  local opts = {
    move_cursor = false,
    duration = duration,
    easing_name = easing,
    winid = winid,
    info = info,
  }
  neoscroll.scroll(lines, opts)
end

---G emulation
---@param half_win_duration number | Zopts Duration of the animation for a scroll of half a window
---@param easing string | nil Easing function to smooth the animation
---@param info table | nil
function neoscroll.G(half_win_duration, easing, info, winid)
  if type(half_win_duration) == "table" then
    local zopts = half_win_duration
    half_win_duration = zopts.half_win_duration
    easing = zopts.easing
    winid = zopts.winid
    info = zopts.info or {}
  end
  local lines = window.get_lines_below(vim.fn.line("w$"))
  local window_height = vim.fn.winheight(0)
  local duration = math.floor(half_win_duration * (math.abs(lines) / (window_height / 2)) + 0.5)
  info.G = true
  local opts = {
    move_cursor = true,
    duration = duration,
    easing_name = easing,
    winid = winid,
    info = info,
  }
  neoscroll.scroll(lines, opts)
end

---gg emulation
---@param half_win_duration number | Zopts Duration of the animation for a scroll of half a window
---@param easing_name string | nil Easing function to smooth the animation
---@param info table | nil
function neoscroll.gg(half_win_duration, easing, info, winid)
  if type(half_win_duration) == "table" then
    local zopts = half_win_duration
    half_win_duration = zopts.half_win_duration
    easing = zopts.easing
    winid = zopts.winid
    info = zopts.info
  end
  local lines = window.get_lines_above(vim.fn.line("w0"))
  local window_height = vim.fn.winheight(winid)
  local cursor_win_line = vim.fn.winline()
  lines = -lines - cursor_win_line
  local duration = math.floor(half_win_duration * (math.abs(lines) / (window_height / 2)) + 0.5)
  local opts = {
    move_cursor = true,
    duration = duration,
    easing = easing,
    winid = winid,
    info = info,
  }
  neoscroll.scroll(lines, opts)
end

neoscroll.telescope_scroll_fn = function(self, direction)
  if not self.state then
    return
  end
  local opts = {}
  for k, v in pairs(config.telescope_scroll_opts) do
    opts[k] = v
  end
  opts.winid = self.state.winid
  neoscroll.scroll(direction, opts)
end

-- stylua: ignore start
local function_mappings = {
  ["<C-u>"] = function() neoscroll.ctrl_u({duration = 250}) end;
  ["<C-d>"] = function() neoscroll.ctrl_d({duration = 250}) end;
  ["<C-b>"] = function() neoscroll.ctrl_b({duration = 450}) end;
  ["<C-f>"] = function() neoscroll.ctrl_f({duration = 450}) end;
  ["<C-y>"] = function() neoscroll.scroll(-0.1, { move_cursor=false; duration = 100}) end;
  ["<C-e>"] = function() neoscroll.scroll(0.1, {move_cursor=false; duration = 100}) end;
  ["zt"]    = function() neoscroll.zt({half_win_duration = 250}) end;
  ["zz"]    = function() neoscroll.zz({half_win_duration = 250}) end;
  ["zb"]    = function() neoscroll.zb({half_win_duration = 250}) end;
  ["G"]     = function() neoscroll.G({half_win_duration = 250}) end;
  ["gg"]    = function() neoscroll.gg({half_win_duration = 250}) end;
}
-- stylua: ignore end

---Checks that the mappings supplied exists in function_mappings
---@param mappings table
local function validate_mappings(mappings)
  for _, keymap_key in ipairs(mappings) do
    if function_mappings[keymap_key] == nil then
      error(
        "'" .. keymap_key .. "' " ..
        "is not part of Neoscroll default mappings.\n" ..
        "See `:help neoscroll-default-mappings` for a list of available mappings\n" ..
        "or create your custom mappings using `:help neoscroll-functions` " ..
        "(see the README for some examples on how to do this)"
      )
    end
  end
end

function neoscroll.setup(custom_opts)
  custom_opts = custom_opts or {}
  -- Validate supplied mappings
  if custom_opts.mappings ~= nil then
      validate_mappings(custom_opts.mappings)
  end
  require("neoscroll.config").set_options(custom_opts)
  local modes = { "n", "v", "x" }
  for _, key in ipairs(config.mappings) do
    vim.keymap.set(modes, key, function_mappings[key])
  end
  vim.cmd("command! NeoscrollEnablePM let b:neoscroll_performance_mode = v:true")
  vim.cmd("command! NeoscrollDisablePM let b:neoscroll_performance_mode = v:false")
  vim.cmd("command! NeoscrollEnableBufferPM let b:neoscroll_performance_mode = v:true")
  vim.cmd("command! NeoscrollDisableBufferPM let b:neoscroll_performance_mode = v:false")
  vim.cmd("command! NeoscrollEnableGlobalPM let g:neoscroll_performance_mode = v:true")
  vim.cmd("command! NeoscrollDisableGlobalePM let g:neoscroll_performance_mode = v:false")
  ---@type deprecated
  vim.cmd("command! NeoscrollDisablGlobalePM let g:neoscroll_performance_mode = v:false")
  if config.performance_mode then
    vim.g.neoscroll_performance_mode = true
  end
end

return neoscroll
