test:
  nvim --headless -c "PlenaryBustedDirectory lua/tests {minimal_init = 'lua/tests/minimal_init.vim'}" 
  # Inside neovim you can run tests with the below command
  # lua require('plenary.test_harness').test_directory('.', {minimal_init = 'minimal_init.vim'})
