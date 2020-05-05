if exists('b:did_ftplugin')
  finish
endif

let b:did_ftplugin = 1

" Elixir Sense server must be started first
call moonshiner#RunElixirSenseServer()
