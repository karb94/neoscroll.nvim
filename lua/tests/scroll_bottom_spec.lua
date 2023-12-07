local function scroll_win_cursor(scrolloff)
  local neoscroll = require("neoscroll")
  local time = 100
  local lines = 7
  local time_tol = 5
  local cursor_start = vim.fn.line(".")
  local window_start = vim.fn.line("w0")
  local cursor_finish, window_finish

  -- Scroll backwards
  neoscroll.scroll(-lines, true, time)
  vim.wait(time + time_tol)
  cursor_finish = vim.fn.line(".")
  window_finish = vim.fn.line("w0")
  assert.equals(window_start - lines, window_finish)
  if not scrolloff then
    assert.equals(cursor_start - lines, cursor_finish)
  end

  -- Scroll forwards
  neoscroll.scroll(lines, true, time)
  vim.wait(time + time_tol)
  cursor_finish = vim.fn.line(".")
  window_finish = vim.fn.line("w0")
  assert.equals(window_start, window_finish)
  if not scrolloff then
    assert.equals(cursor_start, cursor_finish)
  end

end

local motion_opts = {
  stop_eof = false,
  respect_scrolloff = true,
  cursor_scrolls_alone = false,
}

describe("Scrolls from bottom without scrolloff", function()
  local neoscroll = require("neoscroll")
  vim.api.nvim_command('help help | only')

  before_each(function()
    vim.api.nvim_command('normal ggG')
  end)

  for opt1, val1 in pairs(motion_opts) do
    local custom_opts = {[opt1] = val1}
    for opt2, val2 in pairs(motion_opts) do
      custom_opts[opt2] = val2
      for opt3, val3 in pairs(motion_opts) do
        custom_opts[opt3]  = val3
        it(vim.inspect(custom_opts), function()
          neoscroll.setup(custom_opts)
          scroll_win_cursor(vim.wo.scrolloff ~= 0)
        end)
      end
    end
  end
end)

describe("Scrolls from bottom with scrolloff", function()
  local neoscroll = require("neoscroll")
  vim.wo.scrolloff = 3

  before_each(function()
    vim.api.nvim_command('normal ggG')
  end)

  for opt1, val1 in pairs(motion_opts) do
    local custom_opts = {[opt1] = val1}
    for opt2, val2 in pairs(motion_opts) do
      custom_opts[opt2] = val2
      for opt3, val3 in pairs(motion_opts) do
        custom_opts[opt3]  = val3
        it(vim.inspect(custom_opts), function()
          neoscroll.setup(custom_opts)
          scroll_win_cursor(vim.wo.scrolloff ~= 0)
        end)
      end
    end
  end
end)
