let s:path_project = expand('<sfile>:p:h')
let s:se_log_file = $TMP . '\moonshiner-vim-es.log'
let g:IsElixirSenseServerFound = 0

" Run Exlixir Sense server
function! moonshiner#RunElixirSenseServer()
  let l:elixir_sense_script = s:path_project . '.\..\elixir_sense\run.exs'
  silent exec '!start /b elixir ' . l:elixir_sense_script . ' tcpip 0 dev > ' . s:se_log_file
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
      let l:code = substitute(join(getline(1, '$'), '<CR>'), "!", "<EXCLAMATION>", "g")
      let l:nCol = col('.')
      let l:nRow = line('.')
      let l:suggestions = s:GetSuggestions(l:code, l:nCol, l:nRow, a:base)

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
  let l:info = readfile(s:se_log_file)
  return matchlist(l:info[0], '\m\(.*\):\(.*\):\(.*\):\(.*\)$')
endfunction

" Retreive code completion suggestions from Elixir Sense server
function! s:GetSuggestions(code, nCol, nRow, base)
  if (g:IsElixirSenseServerFound != 1)
    let [_, g:es_status, g:es_host, g:es_port, g:es_token; _] = s:FindElixirSenseServer()
    let g:IsElixirSenseServerFound = 1
  endif

  if (g:es_status != 'ok')
    echohl ErrorMsg
    echomsg 'Elixir Sernse server is not available!'
    echohl NONE
    sleep 1000m
    return []
  endif

  let tempname = tempname()
  call writefile([], tempname)
  silent exec '!start /b elixir ' . s:path_project . '.\..\scripts\requests\suggestions.exs '
    \ . g:es_host . ' ' . g:es_port . ' "' . g:es_token . '" "' . a:code . '" '
    \ . a:nRow . ' ' . a:nCol
    \ . ' > ' tempname
  let l:lines = readfile(tempname)

  while (l:lines == []) || (l:lines[-1] != '<EOF>')
    let l:lines = readfile(tempname)
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

  call delete(tempname)
  return l:suggestions
endfunction
