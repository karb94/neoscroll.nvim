describe("some basics",
  function()
    it("can be required",
      function()
        local neoscroll = require("neoscroll")
        local start = vim.fn.line(".")
        local finish = vim.fn.line(".")
        neoscroll.scroll(10, false, 100)
        vim.wait(1000)
        assert.equals(start, finish)
      end
    )
  end
)
