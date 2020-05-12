let s:path_project = expand('<sfile>:p:h')

" Run Exlixir Sense server
function! moonshiner#RunElixirSenseServer(cwd, log_file)
  let l:elixir_sense_script = s:path_project . '.\..\elixir_sense\run.exs'
  let l:deleted = utils#DeleteFile(a:log_file)

  if (l:deleted == 0)
    call writefile([], a:log_file)
    let l:msg = "Please wait! Running Elixir Sense server "
    silent exe '!start /b powershell Start-Process -WorkingDirectory "' . a:cwd . '" -WindowStyle Hidden -RedirectStandardOutput "' . a:log_file . '" -FilePath "elixir" -ArgumentList "' . l:elixir_sense_script . '", "tcpip", "0", "dev"'

    while (readfile(a:log_file) == [])
      sleep 500m
      let l:msg .= '.'
      echo l:msg
    endwhile
  endif
endfunction

" Autocomplete code function
function! moonshiner#Complete(findstart, base)
  if (a:findstart)
    let l:line = getline('.')
    let l:start = col('.') - 1

    while l:start > 0 && l:line[l:start - 1] =~ '\a'
      let l:start -= 1
    endwhile

    return l:start
  else
    let l:filtered_suggestions = []
    let l:nCol = col('.')
    let l:nRow = line('.')
    let l:code = getline(1, '$')
    let l:source_code_path = tempname()
    call writefile(l:code, l:source_code_path)
    let l:suggestions = s:GetSuggestions(l:source_code_path, l:nCol, l:nRow, a:base)
    call delete(l:source_code_path)

    for s in l:suggestions
      if (a:base != "")
        if (s["word"] =~ '^' . a:base)
          call add(l:filtered_suggestions, s)
        endif
      else
       call add(l:filtered_suggestions, s)
      endif
    endfor

    return l:filtered_suggestions
  endif
endfunction

" Retreive Elixir Sense connection string
function! s:FindElixirSenseServer()
  let l:mix_folder = utils#FindMixFile()

  if (l:mix_folder == '')
    let l:cwd = expand('%:p:h')
    let l:se_log_file = $TMP . '\' . utils#ToHex(l:cwd)
  else
    let l:cwd = l:mix_folder
    let l:se_log_file = $TMP . '\' . utils#ToHex(l:mix_folder)
  endif

  call moonshiner#RunElixirSenseServer(l:cwd, l:se_log_file)
  let l:info = readfile(l:se_log_file)
  return matchlist(l:info[0], '\m\(.*\):\(.*\):\(.*\):\(.*\)$')
endfunction

" Retreive code completion suggestions from Elixir Sense server
function! s:GetSuggestions(source_code_path, nCol, nRow, base)
  let [_, g:es_status, g:es_host, g:es_port, g:es_token; _] = s:FindElixirSenseServer()

  if (g:es_status != 'ok')
    echohl ErrorMsg
    echomsg 'Elixir Sernse server is not available!'
    echohl NONE
    sleep 1000m
    return []
  endif

  let l:tempname = tempname()
  call writefile([], l:tempname)
  silent exec '!start /b elixir ' . s:path_project . '.\..\scripts\requests\suggestions.exs '
    \ . g:es_host . ' ' . g:es_port . ' "' . g:es_token . '" "' . a:source_code_path . '" '
    \ . a:nRow . ' ' . a:nCol
    \ . ' > ' l:tempname
  let l:lines = readfile(l:tempname)

  while (l:lines == []) || (l:lines[-1] != '<EOF>')
    let l:lines = readfile(l:tempname)
  endwhile

  let l:suggestions = []

  for line in l:lines
    let l:ml = matchlist(line, 'args:\(.*\), arity:\(.*\), metadata:\(.*\), name:\(.*\), origin:\(.*\), spec:\(.*\), summary:\(.*\), type:\(.*\)$')

    if (len(l:ml) > 0)
      let l:args = l:ml[1]
      let l:arity = l:ml[2]
      let l:metadata = l:ml[3]
      let l:name = l:ml[4]
      let l:origin = l:ml[5]
      let l:spec = l:ml[6]
      let l:summary = l:ml[7]
      let l:type = l:ml[8]

      if (l:type == 'function')
        let l:kind = 'f'
        let l:word = l:name
        let l:abbr = l:name . '/' . l:arity
        let l:menu = l:origin
        let l:info = "Function: " . l:name . "(" . l:args . ")" .
          \ "\nSummary: " . l:summary .
          \ "\nSpec: " . l:spec .
          \ "\nMetadata: " . l:metadata
      endif

      let l:suggestion = {'kind': l:kind, 'word': l:word, 'abbr': l:abbr, 'menu': l:menu, 'info': l:info, 'dup': 1}
      call add(l:suggestions, l:suggestion)
    endif
  endfor

  call delete(l:tempname)
  return l:suggestions
endfunction
