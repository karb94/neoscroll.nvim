# Neoscroll: a smooth scrolling neovim plugin written in lua

## Demo
https://user-images.githubusercontent.com/41967813/121818668-7b36c800-cc80-11eb-8c3a-45a4767b8f05.mp4


## Features
* Smooth scrolling for window movement commands (mappings optional): `<C-u>`, `<C-d>`, `<C-b>`, `<C-f>`, `<C-y>`, `<C-e>`, `zt`, `zz`, `zb`.
* Takes into account folds.
* A single scrolling function that accepts either the number of lines or the percentage of the window to scroll.
* Scroll any window.
* Cursor is hidden while scrolling (optional) for a more pleasing scrolling experience.
* Customizable scrolling behaviour.
* You can use predefined easing functions for the scrolling animation.
* Performance mode that turns off syntax highlighting while scrolling for slower machines or files with heavy regex syntax highlighting.
* Cancel scroll by scrolling in the opposite direction.
* Simulated "stop on key release" when holding down a key to scroll.
* Scroll any window by window-ID


## Installation
You will need neovim 0.5 for this plugin to work. Install it using your favorite plugin manager:

- With [Packer](https://github.com/wbthomason/packer.nvim): `use 'karb94/neoscroll.nvim'`

- With [vim-plug](https://github.com/junegunn/vim-plug): `Plug 'karb94/neoscroll.nvim'`

- With [lazy.nvim](https://github.com/folke/lazy.nvim), create the file `~/.config/nvim/lua/plugins/neoscroll.lua`:
    ```lua
    return {
      "karb94/neoscroll.nvim",
      opts = {},
    }
    ```


## Options
Read `:help neoscroll-options` for a detailed description of all the options.

`setup()` with all the options and their default values:
```lua
require('neoscroll').setup({
  mappings = {                 -- Keys to be mapped to their corresponding default scrolling animation
    '<C-u>', '<C-d>',
    '<C-b>', '<C-f>',
    '<C-y>', '<C-e>',
    'zt', 'zz', 'zb',
  },
  hide_cursor = true,          -- Hide cursor while scrolling
  stop_eof = true,             -- Stop at <EOF> when scrolling downwards
  respect_scrolloff = false,   -- Stop scrolling when the cursor reaches the scrolloff margin of the file
  cursor_scrolls_alone = true, -- The cursor will keep on scrolling even if the window cannot scroll further
  duration_multiplier = 1.0,   -- Global duration multiplier
  easing = 'linear',           -- Default easing function
  pre_hook = nil,              -- Function to run before the scrolling animation starts
  post_hook = nil,             -- Function to run after the scrolling animation ends
  performance_mode = false,    -- Disable "Performance Mode" on all buffers.
  ignored_events = {           -- Events ignored while scrolling
      'WinScrolled', 'CursorMoved'
  },
})
```
You can map a smaller set of default mappings:
```lua
require('neoscroll').setup({ mappings = {'<C-u>', '<C-d>', '<C-b>', '<C-f>'} })
```
Or you can disable all default mappings by passing an empty list:
```lua
require('neoscroll').setup({ mappings = {} })
```
The section below explains how to create your own custom mappings.


## Custom mappings
You can create your own scrolling mappings using the following lua functions:
* `scroll(lines, opts)`
* `ctrl_u`
* `ctrl_d`
* `ctrl_b`
* `ctrl_f`
* `zt(opts)`
* `zz(opts)`
* `zb(opts)`

Read `:help neoscroll.scroll()` and `:help neoscroll-helper-functions` for more
details.

You can use the following syntactic sugar in your init.lua to define lua
function mappings in normal, visual and select modes:
```lua
neoscroll = require('neoscroll')
local keymap = {
  ["<C-u>"] = function() neoscroll.ctrl_u({ duration = 250 }) end;
  ["<C-d>"] = function() neoscroll.ctrl_d({ duration = 250 }) end;
  ["<C-b>"] = function() neoscroll.ctrl_b({ duration = 450 }) end;
  ["<C-f>"] = function() neoscroll.ctrl_f({ duration = 450 }) end;
  ["<C-y>"] = function() neoscroll.scroll(-0.1, { move_cursor=false; duration = 100 }) end;
  ["<C-e>"] = function() neoscroll.scroll(0.1, { move_cursor=false; duration = 100 }) end;
  ["zt"]    = function() neoscroll.zt({ half_win_duration = 250 }) end;
  ["zz"]    = function() neoscroll.zz({ half_win_duration = 250 }) end;
  ["zb"]    = function() neoscroll.zb({ half_win_duration = 250 }) end;
}
local modes = { 'n', 'v', 'x' }
for key, func in pairs(keymap) do
  vim.keymap.set(modes, key, func)
end
```


## Easing functions
By default the scrolling animation has a constant speed (linear), i.e. the time
between each line scroll is constant. If you want to smooth the start and
end of the scrolling animation you can pass the name of one of the easing
functions that Neoscroll provides to the `scroll()` function. You can use any
of the following easing functions: `linear`, `quadratic`, `cubic`, `quartic`,
`quintic`, `circular`, `sine`. Neoscroll will then adjust the time between each
line scroll using the selected easing function. This dynamic time adjustment
can make animations more pleasing to the eye.

To learn more about easing functions here are some useful links:
* [Microsoft documentation](https://docs.microsoft.com/en-us/dotnet/desktop/wpf/graphics-multimedia/easing-functions?view=netframeworkdesktop-4.8)
* [easings.net](https://easings.net/)
* [febucci.com](https://www.febucci.com/2018/08/easing-functions/)

### Examples
Using the same syntactic sugar introduced in _Custom mappings_ we can write the following config:
```lua
neoscroll = require('neoscroll')
neoscroll.setup({
  -- Default easing function used in any animation where
  -- the `easing` argument has not been explicitly supplied
  easing = "quadratic"
})
local keymap = {
  -- Use the "sine" easing function
  ["<C-u>"] = function() neoscroll.ctrl_u({ duration = 250; easing = 'sine' }) end;
  ["<C-d>"] = function() neoscroll.ctrl_d({ duration = 250; easing = 'sine' }) end;
  -- Use the "circular" easing function
  ["<C-b>"] = function() neoscroll.ctrl_b({ duration = 450; easing = 'circular' }) end;
  ["<C-f>"] = function() neoscroll.ctrl_f({ duration = 450; easing = 'circular' }) end;
  -- When no value is passed the `easing` option supplied in `setup()` is used
  ["<C-y>"] = function() neoscroll.scroll(-0.1, { move_cursor=false; duration = 100 }) end;
  ["<C-e>"] = function() neoscroll.scroll(0.1, { move_cursor=false; duration = 100 }) end;
}
local modes = { 'n', 'v', 'x' }
for key, func in pairs(keymap) do
    vim.keymap.set(modes, key, func)
end
```

## `pre_hook` and `post_hook` functions
Set `pre_hook` and `post_hook` functions to run custom code before and/or after
the scrolling animation. The function will be called with the `info` parameter
which can be optionally passed to `scroll()` (or any of the provided wrappers).
This can be used to conditionally run different hooks for different types of
scrolling animations.

For example, if you want to hide the `cursorline` only for `<C-d>`/`<C-u>`
scrolling animations you can do something like this:
```lua
require('neoscroll').setup({
  pre_hook = function(info) if info == "cursorline" then vim.wo.cursorline = false end end,
  post_hook = function(info) if info == "cursorline" then vim.wo.cursorline = true end end
})
local keymap = {
  ["<C-u>"] = function() neoscroll.ctrl_u({ duration = 250; info = 'cursorline' }) end;
  ["<C-d>"] = function() neoscroll.ctrl_d({ duration = 250; info = 'cursorline' }) end;
}
local modes = { 'n', 'v', 'x' }
for key, func in pairs(keymap) do
  vim.keymap.set(modes, key, func)
end
```
Keep in mind that the `info` variable is not restricted to a string. It can
also be a table with multiple key-pair values.


## Known issues
* `<C-u>`, `<C-d>`, `<C-b>`, `<C-f>` mess up macros
([issue](https://github.com/karb94/neoscroll.nvim/issues/9)).


## Acknowledgements
This plugin was inspired by
[vim-smoothie](https://github.com/psliwka/vim-smoothie) and
[neo-smooth-scroll.nvim](https://github.com/cossonleo/neo-smooth-scroll.nvim).
Big thank you to their authors!
