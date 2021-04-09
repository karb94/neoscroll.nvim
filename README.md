# Neoscroll: a simple smooth scrolling plugin written in lua

![demo](https://user-images.githubusercontent.com/41967813/113758483-d5109400-970b-11eb-83b9-0a844cba1d6b.gif)

[High quality video](https://user-images.githubusercontent.com/41967813/113148268-93727b80-9229-11eb-993b-f55ad2bec808.mp4)

## Features
* Smooth scrolling for window movement commands (mappings optional): `<C-u>`, `<C-d>`, `<C-b>`, `<C-f>`, `<C-y>`, `<C-e>`, `zt`, `zz` and `zb`.
* Takes into account folds.
* A single scrolling function that accepts either the number of lines or the percentage of the window to scroll.
* Cursor is hidden while scrolling (optional) for a more pleasing scrolling experience.
* Customizable scrolling behaviour.
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
})
```

## Custom mappings
Your mappings are too long and ugly? Too lazy to create your own mappings? Use the following syntactic sugar in your init.lua to define your own mappings in normal, visual and select modes:
```Lua
require('neoscroll').setup({
    mappings = {}
    -- Set any other options you want
})

local config = require('neoscroll.config')
local t = config.key_to_function
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

config.set_mappings()
```

## Known issues
* Scrolling might stop before reaching the top/bottom of the file when wrapped lines are present.
* `<C-u>`, `<C-d>`, `<C-b>`, `<C-f>` mess up macros ([issue](https://github.com/karb94/neoscroll.nvim/issues/9)).

## Acknowledgements
This plugin was inspired by [vim-smoothie](https://github.com/psliwka/vim-smoothie) and [neo-smooth-scroll.nvim](https://github.com/cossonleo/neo-smooth-scroll.nvim).
Big thank you to their authors!
