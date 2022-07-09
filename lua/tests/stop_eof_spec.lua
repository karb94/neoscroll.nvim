-- print('window height:', vim.api.nvim_win_get_height(0))
-- print('window width:', vim.api.nvim_win_get_width(0))
-- print('window line:', vim.fn.winline())

local function scroll_win_cursor()
  local neoscroll = require("neoscroll")
  local time = 100
  local lines = 7
  local cursor_start = vim.fn.line(".")
  local window_start = vim.fn.line("w0")
  local cursor_finish, window_finish

  -- Scroll forwards
  neoscroll.scroll(lines, true, time)
  vim.wait(time + 100)
  cursor_finish = vim.fn.line(".")
  window_finish = vim.fn.line("w0")
  assert.equals(cursor_start + lines, cursor_finish)
  assert.equals(window_start + lines, window_finish)

  -- Scroll backwards
  neoscroll.scroll(-lines, true, time)
  vim.wait(time + 100)
  cursor_finish = vim.fn.line(".")
  window_finish = vim.fn.line("w0")
  assert.equals(cursor_start, cursor_finish)
  assert.equals(window_start, window_finish)
end

local motion_opts = {
  stop_eof = false,
  respect_scrolloff = true,
  cursor_scrolls_alone = false,
}


describe("Scrolls properly with", function()
  local neoscroll
  before_each(function()
    neoscroll = require("neoscroll")
    vim.api.nvim_command('help help | only')
    vim.api.nvim_command('normal M')
  end)

  for opt1, val1 in pairs(motion_opts) do
    local custom_opts = {[opt1] = val1}
    for opt2, val2 in pairs(motion_opts) do
      custom_opts[opt2] = val2
      for opt3, val3 in pairs(motion_opts) do
        custom_opts[opt3]  = val3
        it(vim.inspect(custom_opts), function()
          neoscroll.setup(custom_opts)
          scroll_win_cursor()
        end)
      end
    end
  end
end)
