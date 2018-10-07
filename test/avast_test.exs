defmodule DaggerTest do
  use ExUnit.Case
  require Logger
  doctest Dagger
  import Dagger.Schema

  test "greets the world" do
    #    d =
    #      %Dagger{}
    #      |> Dagger.state(:x, 0)
    #      |> Dagger.state(:y, 0)
    #      |> Dagger.state(:z, 0)
    #      |> Dagger.target(:prod, [:x, :y], fn %{x: x, y: y} -> x * y end)
    #      |> Dagger.target(:div, [:x, :z], fn %{x: x, z: z} -> x / z end)
    #      |> Dagger.target(:sum, [:prod, :div], fn t ->
    #        Logger.warn(inspect(t))
    #        t.prod + t.div
    #      end)
    #      |> Dagger.sort_targets()
    #      |> Dagger.update(%{x: 3, y: 2, z: 5})
    #    Logger.warn("#{inspect(d)}")

    #    sum = fn t ->
    #      Logger.warn(inspect(t))
    #      t.prod + t.div
    #    end

    #    defmacro wire(keys, do: body) do
    #
    #      IO.puts "keys: #{inspect(keys)}"
    #      IO.puts "body: #{inspect(body)}"
    #      keyword_list =
    #        Enum.map(keys, fn key ->
    #          variable = quote do: var!(unquote(Macro.var(key, __MODULE__)))
    #          {key, variable}
    #        end)
    #
    #      quote do
    #        fn unquote(keyword_list) -> unquote(body) end
    #      end
    #    end

    #    prod = fn %{x: x, y: y} -> x * y end
    #    div = fn %{x: x, z: z} -> x / z end
    #    sum = fn t -> t[:prod] + t[:div] end
    sum = &Dagger.sum/1

    cow = 90

    div =
      wire [:x, :z] do
        x / z
      end

    sum =
      wire [:prod, :div, :big] do
        prod + div + cow + big
      end

    ff =
      wire [:x, :y], cow: 5 do
        x * y
      end

    # action can take states and views
    # action output map or keyword list of states: values

    aa =
      wire [:kitty, :x, :y] do
        %{
          x: y + 1 + kitty,
          y: x + 2
        }
      end

    Logger.error("ff: #{inspect(ff)}")

    schema = %{
      states: [:x, :y, :z],
      targets: %{
        prod: ff,
        #          wire([:x, :y], do: x * y),
        #        prod: {prod, [:x, :y]},
        div: div,
        #        sum: {sum, [:prod, :div]}
        # wire([:prod, :div], do: prod + div)
        sum: sum
      },
      views: %{
        cow: fn -> "meow" end,
        dog: "puppy",
        big: fn -> 100 end
      },
      actions:
        %{
                 kitty: aa,
          #        bunny: {fn e -> %{x: e} end, [], [:x]}
        }
    }

    d =
      Dagger.create(schema)
      |> Dagger.update(%{x: 7, y: 9, z: 5})
       |> Dagger.invoke_action(:kitty, 3)
    Logger.warn("#{inspect(d)}")
    #
    #        |> Dagger.update(%{x: 3, y: 2, z: 5})
  end
end
