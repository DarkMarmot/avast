defmodule DaggerTest do
  use ExUnit.Case
  require Logger
  doctest Dagger

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


    prod = fn %{x: x, y: y} -> x * y end
    div = fn %{x: x, z: z} -> x / z end
    sum = fn t -> t.prod + t.div end

    schema = %{

      states: %{
        x: 3,
        y: 2,
        z: 5
      },

      targets: %{
        prod: {prod, [:x, :y]},
        div: {div, [:x, :z]},
        sum: {sum, [:prod, :div]}
      }

    }

    d = Dagger.create(schema)
        |> Dagger.update(%{x: 7, y: 9, z: 5})
    Logger.warn("#{inspect(d)}")
#
#        |> Dagger.update(%{x: 3, y: 2, z: 5})
  end
end
