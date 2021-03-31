" Smooth scrolling plugin
" Maintainer: https://github.com/karb94

if exists('g:loaded_neoscroll') || !has('nvim-0.5.0')
    finish
endif

let g:neoscroll_no_mappings = get(g:, 'neoscroll_no_mappings', v:false)
let g:neoscroll_hide_cursor = get(g:, 'neoscroll_hide_cursor', v:true)
let g:neoscroll_time_step_move_cursor = get(g:, 'neoscroll_time_step_move_cursor', 8)
let g:neoscroll_time_step_no_move_cursor = get(g:, 'neoscroll_time_step_no_move_cursor', 20)
let g:neoscroll_stop_eof = get(g:, 'neoscroll_stop_eof', v:false)
let g:neoscroll_cursor_scroll = get(g:, 'neoscroll_cursor_scroll', v:false)

if !g:neoscroll_no_mappings
    lua require('neoscroll').set_mappings()
endif

let g:loaded_neoscroll = 1
