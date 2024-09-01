describe("When EOF is reached", function()
  local neoscroll, cursor_start, cursor_finish, window_start, window_finish
  local time = 100
  local time_tol = require("tests.time_tol")
  local lines = 7
  local scroll_opts = {duration = time}
  neoscroll = require("neoscroll")
  vim.api.nvim_command("help help | only")

  before_each(function()
    vim.api.nvim_command("normal ggGM")
    time = 100
    time_tol = 5
    lines = 7
    cursor_start = vim.fn.line(".")
    window_start = vim.fn.line("w0")
  end)

  it("should scroll cursor when cursor_scrolls_alone==true", function()
    neoscroll.setup({ stop_eof = true, cursor_scrolls_alone = true })
    -- Scroll forwards
    -- print('window line:', vim.fn.winline())
    neoscroll.scroll(lines, scroll_opts)
    vim.wait(time + time_tol)
    -- print('window line:', vim.fn.winline())
    cursor_finish = vim.fn.line(".")
    window_finish = vim.fn.line("w0")
    assert.equals(cursor_start + lines, cursor_finish)
    assert.equals(window_start, window_finish)
  end)

  it("should not scroll cursor when cursor_scrolls_alone==false", function()
    neoscroll.setup({ stop_eof = true, cursor_scrolls_alone = false })
    -- Scroll forwards
    neoscroll.scroll(lines, scroll_opts)
    vim.wait(time + time_tol)
    cursor_finish = vim.fn.line(".")
    window_finish = vim.fn.line("w0")
    assert.equals(cursor_start, cursor_finish)
    assert.equals(window_start, window_finish)
  end)
end)
