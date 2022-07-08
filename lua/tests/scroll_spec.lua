describe("some basics",
  function()
    it("can be required",
      function()
        local neoscroll = require("neoscroll")
        vim.api.nvim_command('help help | only')
        vim.api.nvim_command('normal M')
        print('window height:', vim.api.nvim_win_get_height(0))
        print('window width:', vim.api.nvim_win_get_width(0))
        print('window line:', vim.fn.winline())
        vim.api.nvim_command('normal j')
        vim.wait(1000)
        print('window line:', vim.fn.winline())
        local start = vim.fn.line(".")
        neoscroll.scroll(1, true, 100)
        vim.wait(1000)
        local finish = vim.fn.line(".")
        print('start:', start)
        print('finish:', finish)
        print('window line:', vim.fn.winline())
        assert.equals(start+2, finish)
      end
    )
  end
)
