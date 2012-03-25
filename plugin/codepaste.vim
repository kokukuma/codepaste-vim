"=============================================================================
" File: codepaste.vim
" Author: Tatsuya Karino <kokuban.kumasan@gmail.com>
" WebPage: http://github.com/kokukuma/codepaste-vim
" License: BSD
" script type: plugin

if &cp || (exists('g:loaded_code_paste_vim') && g:loaded_code_paste_vim)
    finish
endif
let g:loaded_code_paste_vim = 1

if !executable('curl')
    echohl ErrorMsg | echomsg "Codepaste: require 'curl' command" | echohl None
    finish
endif

command! -nargs=? -range=% Codepaste :call codepaste#Codepaste(<count>,<line1>,<line2>,<f-args>)
