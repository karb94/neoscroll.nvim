" Smooth scrolling plugin
" Maintainer: Carles Rafols i Belles

if exists('g:loaded_neoscroll') || !has('nvim-0.5.0')
    finish
endif

let g:neoscroll_no_mappings = get(g:, 'neoscroll_no_mappings', v:false)
let g:neoscroll_hide_cursor = get(g:, 'neoscroll_hide_cursor', v:true)
let g:neoscroll_stop_eof = get(g:, 'neoscroll_stop_eof', v:true)
let g:neoscroll_respect_scrolloff = get(g:, 'neoscroll_respect_scrolloff', v:false)
let g:neoscroll_cursor_scrolls_alone = get(g:, 'neoscroll_cursor_scrolls_alone', v:true)
let g:neoscroll_performance_mode = get(g:, 'neoscroll_performance_mode', v:false)

if !g:neoscroll_no_mappings
    lua require('neoscroll').set_mappings()
endif

let g:loaded_neoscroll = 1
