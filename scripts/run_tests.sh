#! /bin/sh

nvim --headless -c "PlenaryBustedDirectory ../lua/tests {minimal_init = '../lua/tests/minimal_init.vim'}"

# lua require('plenary.test_harness').test_directory('.', {minimal_init = 'minimal_init.vim'})
