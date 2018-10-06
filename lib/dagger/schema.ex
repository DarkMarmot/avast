defmodule Dagger.Schema do
  alias Dagger.Schema

  #  defmacro wire(keys, do: body) do
  defmacro wire(keys, options \\ [], do: body) do
    #    body = options[:do]

    to_keys = options[:to]
    IO.puts "opts: #{inspect(options[:to])}"

    keys_to_variables =
      Enum.map(keys, fn key ->
        variable = quote do: var!(unquote(Macro.var(key, __MODULE__)))
        {key, variable}
      end)

    map_arg = {:%{}, [], keys_to_variables}

    case to_keys do
        nil ->
          quote do: {fn unquote(map_arg) -> unquote(body) end, unquote(keys)}
        _ ->
          quote do: {fn unquote(map_arg) -> unquote(body) end, unquote(keys), unquote(to_keys)}
    end

#    quote do
#      {fn unquote(map_arg) -> unquote(body) end, unquote(keys)}
#    end
  end
end
