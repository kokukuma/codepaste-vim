"=============================================================================
" File: codepaste.vim
" Author: Tatsuya Karino <kokuban.kumasan@gmail.com>
" WebPage: http://github.com/kokukuma/codepaste-vim
" License: BSD
" Usage:
"   :Codepaste
"     post current buffer to codepaste
"
"   :'<,'>Codepaste
"     post selected text to codepaste.
"
"   :Codepaste -i
"     post current buffer to codepaste and irc channel
"
"   :Codepaste -m
"     create a gist with all open buffers
"
"   :Codepaste -c
"     post current buffer to codepaste and add to clipboard
"
"
" Tips:
"   * if set g:gist_clip_command, gist.vim will copy the gist code
"       with option '-c'.
"
"     # mac
"     let g:gist_clip_command = 'pbcopy'
"
"     # linux
"     let g:gist_clip_command = 'xclip -selection clipboard'
"
"     # others(cygwin?)
"     let g:gist_clip_command = 'putclip'
"
"   * if don't you want to copy URL of the post...
"
"     let g:gist_put_url_to_clipboard_after_post = 0
"
"     or if you want to copy URL and add linefeed at the last of URL,
"
"     let g:gist_put_url_to_clipboard_after_post = 2
"
"     default value is 1.
"
" Todo:
"   * clipboard
"   * irc
"   * multibuffer
"

" what is this ? by karino
let s:save_cpo = &cpo
set cpo&vim


" Codepaste

function! codepaste#Codepaste(count, line1, line2, ...)
  redraw

  " default options
  if !exists('g:codepaste_put_url_to_clipboard_after_post')
      let codepaste_put_url_to_clipboard_after_post = 0
  else
      let codepaste_put_url_to_clipboard_after_post = 
                  \ g:codepaste_put_url_to_clipboard_after_post
  endif
  if !exists('g:codepaste_curl_options')
      let codepaste_curl_options = ""
  else
      let codepaste_curl_options = g:codepaste_curl_options
  endif
  if !exists('g:codepaste_put_url_to_irc_channel_after_post')
      let codepaste_put_url_to_irc_channel_after_post = 0
  else
      let codepaste_put_url_to_irc_channel_after_post = 
                  \ g:codepaste_put_url_to_irc_channel_after_post
  endif

  let codepaste_print_irc_protocol_log = 0


  " default irc data
  if ! exists('g:codepaste_irc_server')
      let g:codepaste_irc_server = 'irc.klab.org'
  endif
  if ! exists('g:codepaste_irc_port')
      let g:codepaste_irc_port = 6667
  endif
  if ! exists('g:codepaste_irc_channel')
      "let g:codepaste_irc_channel = '#gtsubasa'
      let g:codepaste_irc_channel = '#karino'
  endif
  if ! exists('g:codepaste_irc_nickname')
      let g:codepaste_irc_nickname = 'codepaste-user'
  endif

  " get bufname
  let bufname = bufname("%")
  let multibuffer = 0

  " get arguments
  let args = (a:0 > 0) ? s:shellwords(a:1) : []
  for arg in args
      if arg =~ '^\(-i\|--irc\)$\C'
        let codepaste_put_url_to_irc_channel_after_post = 1
      elseif arg =~ '^\(-m\|--multibuffer\)$\C'
        let multibuffer = 1
      elseif arg =~ '^\(-c\|--clipboard\)$\C'
        let codepaste_put_url_to_clipboard_after_post = 1
      elseif arg =~ '^\(-d\|--debug\)$\C'
        let codepaste_print_irc_protocol_log = 1
      endif
  endfor
  unlet args

  " Post to Codepaste
  if multibuffer == 1
      echo "[info] multibuffer"
  else
      " get contents
      if a:count < 1
          " target is all lenge
          let content = join(getline(a:line1, a:line2), "\n")
          echo "file"

      else
          " target is selected lenge
          let save_regcont = @"
          let save_regtype = getregtype('"')
          silent! normal! gvy
          let content = @"
          call setreg('"', save_regcont, save_regtype)
          echo "[info] use vitsual mode"
      endif

      " execute post
      let url = s:CodepastePost(content)

      " after post
      if len(url) > 0
          " post to irc channel
          if codepaste_put_url_to_irc_channel_after_post == 1
              let res = s:post_irc_channel(g:codepaste_irc_server,
                                         \ g:codepaste_irc_port,
                                         \ g:codepaste_irc_channel,
                                         \ g:codepaste_irc_nickname,
                                         \ url,
                                         \ codepaste_print_irc_protocol_log)
              " echo '[info] cannot use irc post yet'
              if res == 1
                  echo '[info] Post to '.g:codepaste_irc_channel
              elseif res == 0
                  echohl ErrorMsg | echomsg '[info] Fail Post to '.g:codepaste_irc_channel | echohl None
              endif
          endif
          " add to clipboard
          if codepaste_put_url_to_clipboard_after_post == 1
              echo '[info] cannot use add clipboard yet'
          endif
      endif
  endif
endfunction

" For fix arguments, string -> list

function! s:shellwords(str)
  let words = split(a:str, '\%(\([^ \t\''"]\+\)\|''\([^\'']*\)''\|"\(\%([^\"\\]\|\\.\)*\)"\)\zs\s*\ze')
  let words = map(words, 'substitute(v:val, ''\\\([\\ ]\)'', ''\1'', "g")')
  let words = map(words, 'matchstr(v:val, ''^\%\("\zs\(.*\)\ze"\|''''\zs\(.*\)\ze''''\|.*\)$'')')
  return words
endfunction

" Post Codepaste

function! s:CodepastePost(content)

    let nickname = ""
    let title    = ""
    let input    = s:encodeURIComponent(a:content)

    " make url
    let url = ' "http://klab.klab.org/cp/store"'
    let nickname = ' -d "nickname=' . nickname .'"'
    let title    = ' -d "title='    . title    .'"'
    let input    = ' -d "input='    . input    .'"'
    let curlcmd = 'curl -i --data-urlencode '. nickname . title . input . url

    " execute curl command
    echo "Postting it to codepaste ..."
    "let res = system('curl -i --data-urlencode '.. url)
    let res = system(curlcmd)

    " get http header
    let headers = split(res, '\(\r\?\n\|\r\n\?\)')
    let location = matchstr(headers, '^Location:')
    let location = matchstr(location, '^[^:]\+: \zs.*')

    "
    "if len(location)>0
    if len(location) > 0 && location =~ '^\(http\|https\):\/\/klab\.klab\.org\/'
        redraw
        echomsg 'Done: '.location
        echomsg ''
    else
        echohl ErrorMsg | echomsg 'Post failed' | echohl None
    endif

    " return
    return location
endfunction

" URL Encode

function! s:encodeURIComponent(instr)
  let instr = iconv(a:instr, &enc, "utf-8")
  let len = strlen(instr)
  let i = 0
  let outstr = ''
  while i < len
    let ch = instr[i]
    if ch =~# '[0-9A-Za-z-._~!''()*]'
      let outstr = outstr . ch
    elseif ch == ' '
      let outstr = outstr . '+'
    else
      let outstr = outstr . '%' . substitute('0' . s:nr2hex(char2nr(ch)), '^.*\(..\)$', '\1', '')
    endif
    let i = i + 1
  endwhile
  return outstr
endfunction

" For URL Encode

function! s:nr2hex(nr)
  let n = a:nr
  let r = ""
  while n
    let r = '0123456789ABCDEF'[n % 16] . r
    let n = n / 16
  endwhile
  return r
endfunction

" Post to irc channel

function! s:post_irc_channel(server, port, channel, nickname, url, print_log_flg)

    let user = "USER test test test test\n"
    let nick = "NICK ".a:nickname."\n"
    let join = "JOIN ".a:channel."\n"
    let msg  = "PRIVMSG ".a:channel." :".a:url."\n"
    let part = "PART ".a:channel."\n"
    let quit = "QUIT : Leaving\n"
    let result = []

    try

        " connect server
        let sock = vimproc#socket_open(a:server, a:port)
        " sockがnullだったらsocket error としてthrowしたかったが、
        " socket_openの中でthrowしてるっぽい？
        " 中身読むか
        " if sock.eof == 0 
        "     throw "SOCKET ERROR"
        " endif

        " login
        call sock.write(user)
        call sock.write(nick)
        call sock.write(join)

        " post
        call sock.write(msg)

        " leave
        call sock.write(part)
        call sock.write(quit)


        let res = ''
        while !sock.eof
            let res .= sock.read()
            " ホントは,IRCサーバからの戻り値の中に特定の文字
            " ERRORとかがあったらthrowするようにしたい。
            "
            " let rn = stridx(res2,'ERROR')
            " if rn >= 0
            "     "echo "throw"
            "     throw "PROTO ERROR"
            " endif
        endwhile

        " check 
        "let rn = 
        if res == ''
            throw "SOCKET ERROR"
        elseif stridx(res,'JOIN') < 0
            throw "IRC PROTOCOL ERROR"
        endif

        " print irc protocol log
        if a:print_log_flg == 1
            echo res
        endif

        " close connection
        call sock.close()
        unlet sock

        return 1
    catch /SOCKET ERROR/
        echohl ErrorMsg | echo socket error  | echohl None
        return 0
    catch /IRC PROTOCOL ERROR/
        echohl ErrorMsg | echo res | echohl None

        " close connection
        call sock.close()
        unlet sock
        return 0
    catch 
        echohl ErrorMsg | echo "socket error"  | echohl None
        return 0
    endtry

endfunction

" Complete List

function! codepaste#complete_source(arglead, cmdline, cursorpos)
   return ['--irc','--debug']
   "return ['--irc','--debug','--multibuffer','--clipboard']
endfunction

" what is this ? by karino
let &cpo = s:save_cpo
unlet s:save_cpo
