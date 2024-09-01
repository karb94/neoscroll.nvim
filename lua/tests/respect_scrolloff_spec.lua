describe("When BOF is reached", function()
  local neoscroll, cursor_start, cursor_finish, window_start, window_finish
  local time = 100
  local time_tol = require("tests.time_tol")
  local opts = { stop_eof = true, cursor_scrolls_alone = true }
  local scroll_opts = {duration = time}
  neoscroll = require("neoscroll")
  vim.api.nvim_command("help help | only")

  before_each(function()
    vim.api.nvim_command("normal ggM")
    cursor_start = vim.fn.line(".")
    window_start = vim.fn.line("w0")
  end)

  it("should scroll cursor till top when respect_scrolloff==false", function()
    local scrolloff = 0
    vim.go.scrolloff = scrolloff
    opts.respect_scrolloff = false
    neoscroll.setup(opts)
    -- Scroll forwards
    neoscroll.scroll(-(cursor_start - 1), scroll_opts)
    vim.wait(time + time_tol)
    cursor_finish = vim.fn.line(".")
    window_finish = vim.fn.line("w0")
    assert.equals(scrolloff + 1, cursor_finish)
    assert.equals(window_start, window_finish)
  end)

  it("should scroll cursor till top when respect_scrolloff==true and go.scrolloff==0", function()
    local scrolloff = 0
    vim.go.scrolloff = scrolloff
    opts.respect_scrolloff = true
    neoscroll.setup(opts)
    -- Scroll forwards
    neoscroll.scroll(-(cursor_start - 1), scroll_opts)
    vim.wait(time + time_tol)
    cursor_finish = vim.fn.line(".")
    window_finish = vim.fn.line("w0")
    assert.equals(scrolloff + 1, cursor_finish)
    assert.equals(window_start, window_finish)
  end)

  it(
    "should not scroll cursor till top when respect_scrolloff==true and go.scrolloff==5",
    function()
      local scrolloff = 5
      vim.go.scrolloff = scrolloff
      opts.respect_scrolloff = true
      neoscroll.setup(opts)
      -- scroll forwards
      neoscroll.scroll(-(cursor_start - 1), scroll_opts)
      vim.wait(time + time_tol)
      cursor_finish = vim.fn.line(".")
      window_finish = vim.fn.line("w0")
      assert.equals(scrolloff + 1, cursor_finish)
      assert.equals(window_start, window_finish)
    end
  )

  it(
    "should not scroll cursor till top when respect_scrolloff==true and wo.scrolloff==5",
    function()
      local scrolloff = 5
      vim.go.scrolloff = 0
      vim.wo.scrolloff = scrolloff
      opts.respect_scrolloff = true
      neoscroll.setup(opts)
      -- scroll forwards
      neoscroll.scroll(-(cursor_start - 1), scroll_opts)
      vim.wait(time + time_tol)
      cursor_finish = vim.fn.line(".")
      window_finish = vim.fn.line("w0")
      assert.equals(scrolloff + 1, cursor_finish)
      assert.equals(window_start, window_finish)
    end
  )
end)

describe("When EOF is reached", function()
  local neoscroll, cursor_start, cursor_finish, window_start, window_finish
  local time = 100
  local time_tol = 5
  local opts = { stop_eof = true, cursor_scrolls_alone = true }
  local last_line = vim.fn.line("$")
  local lines
  local scroll_opts = {duration = time}
  vim.wo.scrolloff = -1
  neoscroll = require("neoscroll")

  before_each(function()
    vim.api.nvim_command("normal ggGM")
    -- vim.api.nvim_command([[exec "normal! \<c-e>"]])
    cursor_start = vim.fn.line(".")
    window_start = vim.fn.line("w0")
    lines = last_line - cursor_start + 1 -- +1 to make sure it stops and doesn't go further
  end)

  it("should scroll cursor till bottom when respect_scrolloff==false", function()
    local scrolloff = 0
    vim.go.scrolloff = scrolloff
    opts.respect_scrolloff = false
    neoscroll.setup(opts)
    -- Scroll forwards
    neoscroll.scroll(lines, scroll_opts)
    vim.wait(time + time_tol)
    cursor_finish = vim.fn.line(".")
    window_finish = vim.fn.line("w0")
    assert.equals(last_line, cursor_finish)
    assert.equals(window_start, window_finish)
  end)

  it("should scroll cursor till bottom when respect_scrolloff==true and go.scrolloff==0", function()
    local scrolloff = 0
    vim.go.scrolloff = scrolloff
    opts.respect_scrolloff = true
    neoscroll.setup(opts)
    -- Scroll forwards
    neoscroll.scroll(lines, scroll_opts)
    vim.wait(time + time_tol)
    cursor_finish = vim.fn.line(".")
    window_finish = vim.fn.line("w0")
    assert.equals(last_line, cursor_finish)
    assert.equals(window_start, window_finish)
  end)

  it(
    "should not scroll cursor till top when respect_scrolloff==true and go.scrolloff==5",
    function()
      local scrolloff = 5
      vim.go.scrolloff = scrolloff
      opts.respect_scrolloff = true
      neoscroll.setup(opts)
      -- Scroll forwards
      neoscroll.scroll(lines, scroll_opts)
      vim.wait(time + time_tol)
      cursor_finish = vim.fn.line(".")
      window_finish = vim.fn.line("w0")
      assert.equals(last_line - scrolloff, cursor_finish)
      assert.equals(window_start, window_finish)
    end
  )

  it(
    "should not scroll cursor till top when respect_scrolloff==true and wo.scrolloff==5",
    function()
      local scrolloff = 5
      vim.go.scrolloff = 0
      vim.wo.scrolloff = scrolloff
      opts.respect_scrolloff = true
      neoscroll.setup(opts)
      -- Scroll forwards
      neoscroll.scroll(lines, scroll_opts)
      vim.wait(time + time_tol)
      cursor_finish = vim.fn.line(".")
      window_finish = vim.fn.line("w0")
      assert.equals(last_line - scrolloff, cursor_finish)
      assert.equals(window_start, window_finish)
    end
  )
end)

describe("When beyond EOF", function()
  local neoscroll, cursor_start, cursor_finish, window_start, window_finish
  local time = 100
  local time_tol = 5
  local opts = { stop_eof = false, cursor_scrolls_alone = true }
  local lines = vim.fn.winheight(0)
  local scroll_opts = {duration = time}
  vim.wo.scrolloff = -1
  neoscroll = require("neoscroll")
  local last_line = vim.fn.line("$")

  before_each(function()
    vim.api.nvim_command("normal ggGM")
    vim.api.nvim_command([[exec "normal! \<c-e>"]])
    cursor_start = vim.fn.line(".")
    window_start = vim.fn.line("w0")
  end)

  it("should scroll cursor till bottom when respect_scrolloff==false", function()
    local scrolloff = 0
    vim.go.scrolloff = scrolloff
    opts.respect_scrolloff = false
    neoscroll.setup(opts)
    -- Scroll forwards
    neoscroll.scroll(lines, scroll_opts)
    vim.wait(time + time_tol)
    cursor_finish = vim.fn.line(".")
    window_finish = vim.fn.line("w0")
    assert.equals(last_line, cursor_finish)
    assert.equals(window_start + (cursor_finish - cursor_start), window_finish)
  end)

  it("should scroll cursor till bottom when respect_scrolloff==true and go.scrolloff==0", function()
    local scrolloff = 0
    vim.go.scrolloff = scrolloff
    opts.respect_scrolloff = true
    neoscroll.setup(opts)
    -- Scroll forwards
    neoscroll.scroll(lines, scroll_opts)
    vim.wait(time + time_tol)
    cursor_finish = vim.fn.line(".")
    window_finish = vim.fn.line("w0")
    assert.equals(last_line, cursor_finish)
    assert.equals(window_start + (cursor_finish - cursor_start), window_finish)
  end)

  it(
    "should not scroll cursor till top when respect_scrolloff==true and go.scrolloff==5",
    function()
      local scrolloff = 5
      vim.go.scrolloff = scrolloff
      opts.respect_scrolloff = true
      neoscroll.setup(opts)
      -- Scroll forwards
      neoscroll.scroll(lines, scroll_opts)
      vim.wait(time + time_tol)
      cursor_finish = vim.fn.line(".")
      window_finish = vim.fn.line("w0")
      assert.equals(last_line - scrolloff, cursor_finish)
      assert.equals(window_start + (cursor_finish - cursor_start), window_finish)
    end
  )

  it(
    "should not scroll cursor till top when respect_scrolloff==true and wo.scrolloff==5",
    function()
      local scrolloff = 5
      vim.go.scrolloff = 0
      vim.wo.scrolloff = scrolloff
      opts.respect_scrolloff = true
      neoscroll.setup(opts)
      -- Scroll forwards
      neoscroll.scroll(lines, scroll_opts)
      vim.wait(time + time_tol)
      cursor_finish = vim.fn.line(".")
      window_finish = vim.fn.line("w0")
      assert.equals(last_line - scrolloff, cursor_finish)
      assert.equals(window_start + (cursor_finish - cursor_start), window_finish)
    end
  )
end)
