if exists('g:neoscroll_loaded') || !has('nvim-0.5.0')
    finish
endif

let g:charblob_loaded = 1

if exists('g:neoscroll_loaded')
    finish
endif

let g:neoscroll_times_step_move_cursor = get(g:, 'neoscroll_times_step_move_cursor', 8)
let g:neoscroll_times_step_no_move_cursor = get(g:, 'neoscroll_times_step_no_move_cursor', 20)
