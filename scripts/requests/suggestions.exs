# Type: Elixir script
# Purpose: Send a request code suggestion to Elixir Sense server via TCP/IP socket
# Mandatory arguments:
#  - host: hostname of the server
#  - port: listening port of the server
#  - token: secure token in order to send request
#  - code: preformated Elixir source code
#  - line, column: cursor position on the source code

[host, port, token, code, line, column] = System.argv

source_code = code
              |> String.replace("<CR>", "\n")
              |> String.replace("<EXCLAMATION>", "!")

{:ok, socket} = :gen_tcp.connect(to_charlist(host), String.to_integer(port), [:binary, active: false, packet: 4])

request = %{
  "request_id" => 1,
  "auth_token" => token,
  "request" => "suggestions",
  "payload" => %{
    "buffer" => source_code,
    "line" => String.to_integer(line),
    "column" => String.to_integer(column)
  }
}

data = :erlang.term_to_binary(request)
:ok = :gen_tcp.send(socket, data)
{:ok, bin_response} = :gen_tcp.recv(socket, 0)
response = :erlang.binary_to_term(bin_response)

fun = fn(x) ->
  if x.type == :function do
    args = x.args                    # "enumerable, count"
    arity = x.arity                  # 2
    name = x.name                    # "chunk_every"
    origin = x.origin                # "Enum"
    spec = String.replace(x.spec, "@spec ", "")    # "@spec chunk_every(t, pos_integer) :: [list]"
    summary = String.replace(x.summary, "\n", " ") # "Shortcut to `chunk_every(enumerable, count, count)`.\n"
    type = x.type                    # :function
    metadata = Map.keys(x.metadata)  # %{since: "1.5.0"}
               |> Enum.map(fn key -> "#{key}: #{x.metadata[key]}" end)
               |> Enum.join(",")
    IO.puts "args:#{args}, arity:#{arity}, metadata:#{metadata}, name:#{name}, origin:#{origin}, spec:#{spec}, summary:#{summary}, type:#{type}"
  end
end

if response.error == nil do
  payloads = response.payload
  Enum.each(payloads, fun)
end

IO.puts "<EOF>"
