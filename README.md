# Neoscroll: a smooth scrolling neovim plugin written in lua

## Demo
https://user-images.githubusercontent.com/41967813/121818668-7b36c800-cc80-11eb-8c3a-45a4767b8f05.mp4


## Features
* Smooth scrolling for window movement commands (mappings optional): `<C-u>`, `<C-d>`, `<C-b>`, `<C-f>`, `<C-y>`, `<C-e>`, `zt`, `zz`, `zb`.
* Takes into account folds.
* A single scrolling function that accepts either the number of lines or the percentage of the window to scroll.
* Cursor is hidden while scrolling (optional) for a more pleasing scrolling experience.
* Customizable scrolling behaviour.
* You can use predefined easing functions for the scrolling animation.
* Performance mode that turns off syntax highlighting while scrolling for slower machines or files with heavy regex syntax highlighting.
* Cancel scroll by scrolling in the opposite direction.
* Simulated "stop on key release" when holding down a key to scroll.

## Installation
You will need neovim 0.5 for this plugin to work. Install it using your favorite plugin manager:

- With [Packer](https://github.com/wbthomason/packer.nvim): `use 'karb94/neoscroll.nvim'`

- With [vim-plug](https://github.com/junegunn/vim-plug): `Plug 'karb94/neoscroll.nvim'`

- With [lazy.nvim](https://github.com/folke/lazy.nvim), create the file `~/.config/nvim/lua/plugins/neoscroll.lua`:
    ```Lua
    return {
      "karb94/neoscroll.nvim",
      config = function ()
        require('neoscroll').setup {}
      end
    }
    ```

## Quickstart
Add the `setup()` function to your init file.

For `init.lua`:
```Lua
require('neoscroll').setup()
```
For `init.vim`:
```Vim
lua require('neoscroll').setup()
```


## Options
Setup function with all the options and their default values:
```Lua
require('neoscroll').setup({
    -- All these keys will be mapped to their corresponding default scrolling animation
    mappings = {'<C-u>', '<C-d>', '<C-b>', '<C-f>',
                '<C-y>', '<C-e>', 'zt', 'zz', 'zb'},
    hide_cursor = true,          -- Hide cursor while scrolling
    stop_eof = true,             -- Stop at <EOF> when scrolling downwards
    respect_scrolloff = false,   -- Stop scrolling when the cursor reaches the scrolloff margin of the file
    cursor_scrolls_alone = true, -- The cursor will keep on scrolling even if the window cannot scroll further
    easing_function = nil,       -- Default easing function
    pre_hook = nil,              -- Function to run before the scrolling animation starts
    post_hook = nil,             -- Function to run after the scrolling animation ends
    performance_mode = false,    -- Disable "Performance Mode" on all buffers.
})
```


## Custom mappings
You can create your own scrolling mappings using the following lua functions:
* `scroll(lines, move_cursor, time[, easing])`
* `zt(half_win_time[, easing])`
* `zz(half_win_time[, easing])`
* `zb(half_win_time[, easing])`

Read the documentation for more details on how to use each function.

You can use the following syntactic sugar in your init.lua to define lua function mappings in normal, visual
and select modes:
```Lua
require('neoscroll').setup({
    -- Set any options as needed
})

local t = {}
-- Syntax: t[keys] = {function, {function arguments}}
t['<C-u>'] = {'scroll', {'-vim.wo.scroll', 'true', '250'}}
t['<C-d>'] = {'scroll', { 'vim.wo.scroll', 'true', '250'}}
t['<C-b>'] = {'scroll', {'-vim.api.nvim_win_get_height(0)', 'true', '450'}}
t['<C-f>'] = {'scroll', { 'vim.api.nvim_win_get_height(0)', 'true', '450'}}
t['<C-y>'] = {'scroll', {'-0.10', 'false', '100'}}
t['<C-e>'] = {'scroll', { '0.10', 'false', '100'}}
t['zt']    = {'zt', {'250'}}
t['zz']    = {'zz', {'250'}}
t['zb']    = {'zb', {'250'}}

require('neoscroll.config').set_mappings(t)
```


## Easing functions
By default the scrolling animation has a constant speed, i.e. the time between each line scroll is constant. 
If you want to smooth the start and/or end of the scrolling animation you can pass the name of one of the
easing functions that Neoscroll provides to the `scroll()` function. You can use any of the following easing
functions: `quadratic`, `cubic`, `quartic`, `quintic`, `circular`, `sine`. Neoscroll will then adjust the time
between each line scroll using the selected easing function. This dynamic time adjustment can make animations
more pleasing to the eye.

To learn more about easing functions here are some useful links:
* [Microsoft documentation](https://docs.microsoft.com/en-us/dotnet/desktop/wpf/graphics-multimedia/easing-functions?view=netframeworkdesktop-4.8)
* [easings.net](https://easings.net/)
* [febucci.com](https://www.febucci.com/2018/08/easing-functions/)

### Examples
Using the same syntactic sugar introduced in _Custom mappings_ we can write the following config:
```Lua
require('neoscroll').setup({
    easing_function = "quadratic" -- Default easing function
    -- Set any other options as needed
})

local t = {}
-- Syntax: t[keys] = {function, {function arguments}}
-- Use the "sine" easing function
t['<C-u>'] = {'scroll', {'-vim.wo.scroll', 'true', '350', [['sine']]}}
t['<C-d>'] = {'scroll', { 'vim.wo.scroll', 'true', '350', [['sine']]}}
-- Use the "circular" easing function
t['<C-b>'] = {'scroll', {'-vim.api.nvim_win_get_height(0)', 'true', '500', [['circular']]}}
t['<C-f>'] = {'scroll', { 'vim.api.nvim_win_get_height(0)', 'true', '500', [['circular']]}}
-- Pass "nil" to disable the easing animation (constant scrolling speed)
t['<C-y>'] = {'scroll', {'-0.10', 'false', '100', nil}}
t['<C-e>'] = {'scroll', { '0.10', 'false', '100', nil}}
-- When no easing function is provided the default easing function (in this case "quadratic") will be used
t['zt']    = {'zt', {'300'}}
t['zz']    = {'zz', {'300'}}
t['zb']    = {'zb', {'300'}}

require('neoscroll.config').set_mappings(t)
```

## `pre_hook` and `post_hook` functions
Set `pre_hook` and `post_hook` functions to run custom code before and/or after the scrolling animation.
The function will be called with the `info` parameter which can be optionally passed to `scroll()` (or any of the provided wrappers). This can be used to conditionally run different hooks for different types of scrolling
animations.

For example, if you want to hide the `cursorline` only for `<C-d>`/`<C-u>` scrolling animations
you can do something like this:
```lua
require('neoscroll').setup({
    pre_hook = function(info) if info == "cursorline" then vim.wo.cursorline = false end end,
    post_hook = function(info) if info == "cursorline" then vim.wo.cursorline = true end end
})
local t = {}
t['<C-u>'] = { 'scroll', { '-vim.wo.scroll', 'true', '350', 'sine', [['cursorline']] } }
t['<C-d>'] = { 'scroll', {  'vim.wo.scroll', 'true', '350', 'sine', [['cursorline']] } }
require('neoscroll.config').set_mappings(t)
```
Keep in mind that the `info` variable is not restricted to a string. It can also be a table with multiple
key-pair values.


## Known issues
* `<C-u>`, `<C-d>`, `<C-b>`, `<C-f>` mess up macros ([issue](https://github.com/karb94/neoscroll.nvim/issues/9)).


## Acknowledgements
This plugin was inspired by [vim-smoothie](https://github.com/psliwka/vim-smoothie) and [neo-smooth-scroll.nvim](https://github.com/cossonleo/neo-smooth-scroll.nvim).
Big thank you to their authors!
