alias t := test
alias f := format

# Inside neovim you can run tests with the below command
# lua require('plenary.test_harness').test_directory('.', {minimal_init = 'minimal_init.vim'})
# Run tests in Neovim headless mode
test:
  nvim --headless -c "PlenaryBustedDirectory lua/tests {minimal_init = 'lua/tests/minimal_init.vim'}" 

# Format lua files with stylua
format:
  stylua lua/
