" Find 'mix.exs' file in current project and return its path
function! utils#FindMixFile() abort
  let l:current_dir = expand('%:p:h')
  let l:sub_dir = ''

  while (l:current_dir != fnamemodify(l:current_dir, ':h'))
    if filereadable(l:current_dir  . '\' . 'mix.exs')
      return l:current_dir
    endif

    let l:current_dir = fnamemodify(l:current_dir, ':h')
  endwhile

  return ''
endfunction

" Convert string into HEX
function! utils#ToHex(str) abort
  let l:s = ''

  for c in split(a:str, '\zs')
    let l:s .= printf("%x", char2nr(c))
  endfor

  return l:s
endfunction

" Try to delete file and return a result
function! utils#DeleteFile(file)
  if (!filereadable(a:file))
    return 0
  else
    return delete(a:file)
  endif
endfunction
