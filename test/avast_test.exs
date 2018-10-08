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
#    sum = &Dagger.sum/1
#
#    cow = 90
#
#    div =
#      wire [:x, :z] do
#        x / z
#      end
#
#    sum =
#      wire [:prod, :div, :big] do
#        prod + div + cow + big
#      end
#
#    ff =
#      wire [:x, :y], cow: 5 do
#        x * y
#      end

    # action can take states and views
    # action output map or keyword list of states: values

    move_cmd =
      wire [:move_cmd, :sector] do

        {x, y} = move_cmd

        updates = %{
          x: x,
          y: y,
          sector: {Integer.floor_div(x, 50), Integer.floor_div(y, 50)},
          last_sector: sector
        }

      end

    sector_changed =
      wire [:move_cmd, :sector, :last_sector] do
        sector != last_sector
      end

    sector_set =
      wire [:sector_changed, :sector] do
        []
      end

    schema = %{
      states: [:x, :y, :sector, :last_sector],
      effects: %{
        sector_changed: sector_changed
      },
      targets: %{
        sector_set: sector_set
      },
      views: %{
      },
      actions: %{
        move_cmd: move_cmd
      }
    }

    d =
      Dagger.create(schema)
#      |> Dagger.update(%{x: 7, y: 9})
      |> Dagger.invoke_action(:move_cmd, {150, 310})
#      |> Dagger.invoke_action(:kitty, 3)

    Logger.warn("#{inspect(d)}")
    #
    #        |> Dagger.update(%{x: 3, y: 2, z: 5})
  end
end
