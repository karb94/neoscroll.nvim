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
    cursor_start = vim.fn.line(".")
    window_start = vim.fn.line("w0")
  end)

  it("should not scroll window further when stop_eof==true", function()
    neoscroll.setup({ stop_eof = true })
    -- Scroll forwards
    neoscroll.scroll(lines, scroll_opts)
    vim.wait(time + time_tol)
    cursor_finish = vim.fn.line(".")
    window_finish = vim.fn.line("w0")
    assert.equals(cursor_start + lines, cursor_finish)
    assert.equals(window_start, window_finish)
  end)

  it("should not scroll window further when stop_eof==false", function()
    neoscroll.setup({ stop_eof = false })
    -- Scroll forwards
    neoscroll.scroll(lines, scroll_opts)
    vim.wait(time + time_tol)
    cursor_finish = vim.fn.line(".")
    window_finish = vim.fn.line("w0")
    assert.equals(cursor_start + lines, cursor_finish)
    assert.equals(window_start + lines, window_finish)
  end)
end)
