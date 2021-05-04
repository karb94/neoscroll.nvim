# Neoscroll: a simple smooth scrolling plugin written in lua

[High quality video](https://user-images.githubusercontent.com/41967813/113148268-93727b80-9229-11eb-993b-f55ad2bec808.mp4)


## Features
* Smooth scrolling for window movement commands (mappings optional): `<C-u>`, `<C-d>`, `<C-b>`, `<C-f>`, `<C-y>`, `<C-e>`, `zt`, `zz` and `zb`.
* Takes into account folds.
* A single scrolling function that accepts either the number of lines or the percentage of the window to scroll.
* Cursor is hidden while scrolling (optional) for a more pleasing scrolling experience.
* Customizable scrolling behaviour.
* Use custom easing functions for the scrolling animation.
* Performance mode that turns off syntax highlighting while scrolling for slower machines or files with heavy regex syntax highlighting.

## Installation
You will need neovim 0.5 for this plugin to work. Install it using your favorite plugin manager:

- With [Packer](https://github.com/wbthomason/packer.nvim): `use 'karb94/neoscroll.nvim'`

- With [vim-plug](https://github.com/junegunn/vim-plug): `Plug 'karb94/neoscroll.nvim'`


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
    -- All these keys will be mapped. Pass an empty table ({}) for no mappings
    mappings = {'<C-u>', '<C-d>', '<C-b>', '<C-f>',
                '<C-y>', '<C-e>', 'zt', 'zz', 'zb'},
    hide_cursor = true,          -- Hide cursor while scrolling
    stop_eof = true,             -- Stop at <EOF> when scrolling downwards
    respect_scrolloff = false,   -- Stop scrolling when the cursor reaches the scrolloff margin of the file
    cursor_scrolls_alone = true  -- The cursor will keep on scrolling even if the window cannot scroll further
    easing = false,              -- easing_function will be used in all scrolling animations with some defaults
    easing_function = function(x) return math.pow(x, 2) end -- default easing function

})
```


## Custom mappings
Your mappings are too long and ugly? Too lazy to create your own mappings? Use the following syntactic sugar in your init.lua to define your own mappings in normal, visual and select modes:
```Lua
require('neoscroll').setup({
    mappings = {'<C-u>', '<C-d>', '<C-b>', '<C-f>',
                '<C-y>', '<C-e>', 'zt', 'zz', 'zb'},
    -- Set any other options as needed
})

local t = {}
-- Syntax: t[keys] = {function, {function arguments}}
t['<C-u>'] = {'scroll', {'-vim.wo.scroll', 'true', '8'}}
t['<C-d>'] = {'scroll', { 'vim.wo.scroll', 'true', '8'}}
t['<C-b>'] = {'scroll', {'-vim.api.nvim_win_get_height(0)', 'true', '7'}}
t['<C-f>'] = {'scroll', { 'vim.api.nvim_win_get_height(0)', 'true', '7'}}
t['<C-y>'] = {'scroll', {'-0.10', 'false', '20'}}
t['<C-e>'] = {'scroll', { '0.10', 'false', '20'}}
t['zt']    = {'zt', {'7'}}
t['zz']    = {'zz', {'7'}}
t['zb']    = {'zb', {'7'}}

require('neoscroll.config').set_mappings(t)
```


## Custom scrolling animations (easing functions)
By default the scrolling animation has a constant speed, i.e. the time-step between each line scroll is constant. 
If you want to smooth the start and/or end of the scrolling animation you can pass an easing function to the
`scroll()` function followed by the first and the last time-step of the scrolling animation. Neoscroll will then
interpolate the time-step using the provided easing function. This dynamic time-step can make animations more
pleasing to the eye.

The easing function provided must be of the form _f(x)_ where _x_ is a value in the range [0,1] denoting the
relative position and _f(x)_ is a value in the range [0,1] that represents the relative time. To learn more about
easing functions here are some useful links:
* [Microsoft documentation](https://docs.microsoft.com/en-us/dotnet/desktop/wpf/graphics-multimedia/easing-functions?view=netframeworkdesktop-4.8)
* [easings.net](https://easings.net/)
* [febucci.com](https://www.febucci.com/2018/08/easing-functions/)

Syntax: `scroll(lines, move_cursor, [easing function], [first time-step], [last time-step])`
### Examples
Using the same syntactic sugar introduced in _Custom mappings_ we can write the following config:
```Lua
require('neoscroll').setup({
    mappings = {'<C-u>', '<C-d>', '<C-b>', '<C-f>',
                '<C-y>', '<C-e>', 'zt', 'zz', 'zb'},
    -- Set any other options as needed
})

-- easing1: f(x) = x^2
local easing1 = [[function(x) return math.pow(x, 2) end]]
-- easing2: f(x) = x^4
local easing2 = [[function(x) return math.pow(x, 4) end]]

local t = {}
-- Syntax: t[keys] = {function, {function arguments}}
-- Use easing1 function from 7 ms to 15 ms time-step
t['<C-u>'] = {'scroll', {'-vim.wo.scroll', 'true', '7', '15', easing1}}
t['<C-d>'] = {'scroll', { 'vim.wo.scroll', 'true', '7', '15', easing1}}
-- Use easing2 function from 5 ms to 20 ms time-step
t['<C-b>'] = {'scroll', {'-vim.api.nvim_win_get_height(0)', 'true', '5', '20', easing2}}
t['<C-f>'] = {'scroll', { 'vim.api.nvim_win_get_height(0)', 'true', '5', '20', easing2}}
-- Use the default easing function defined in easing_function from 20 ms to 30 ms time-step
t['<C-y>'] = {'scroll', {'-0.10', 'false', '20', '30'}}
t['<C-e>'] = {'scroll', { '0.10', 'false', '20', '30;}}
-- Use a constant time-step of 7 ms
t['zt']    = {'zt', {'7'}}
t['zz']    = {'zz', {'7'}}
t['zb']    = {'zb', {'7'}}

require('neoscroll.config').set_mappings(t)
```


## Known issues
* Scrolling might stop before reaching the top/bottom of the file when wrapped lines are present.
* `<C-u>`, `<C-d>`, `<C-b>`, `<C-f>` mess up macros ([issue](https://github.com/karb94/neoscroll.nvim/issues/9)).


## Acknowledgements
This plugin was inspired by [vim-smoothie](https://github.com/psliwka/vim-smoothie) and [neo-smooth-scroll.nvim](https://github.com/cossonleo/neo-smooth-scroll.nvim).
Big thank you to their authors!
