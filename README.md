# Neoscroll: a simple smooth scrolling plugin written in lua

## Installation
You will need neovim 5.0 for this plugin to work
Install using your favorite plugin manager. If you use [Packer](https://github.com/wbthomason/packer.nvim):
```
use 'karb94/neoscroll.nvim'
```

## Features
* Smooth scrolling for window movement commands (optional): `<C-u>`, `<C-d>`, `<C-b>`, `<C-f>`, `<C-y>` and `<C-e>`.
* Takes into account folds.
* A single scrolling function that accepts either the number of lines or the percentage of the window to scroll.
* Cursor is hidden while scrolling (optional) for a more pleasing scrolling experience.

##Acknowledgements
This plugin was inspired by [vim-smoothie](https://github.com/psliwka/vim-smoothie) and [neo-smooth-scroll.nvim](https://github.com/cossonleo/neo-smooth-scroll.nvim).
Big thank you to their authors!
