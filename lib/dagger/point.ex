
defmodule Dagger.Point do
  alias Dagger.Point

  defstruct name: nil, value: nil, sources: MapSet.new(), outputs: MapSet.new(), formula: nil, type: nil

  # triggers are a list of functions mapped to actions -- take event and return boolean

  # points can be type:
  # action  --  has sources and outputs and formula and external trigger
  # state   --  no sources, no formula
  # target  --  has sources and formula
  # view    --  no sources and formula

  # event   -- emitted
  # trigger -- map/filter to action

  @type name_set :: MapSet.t(atom)

  @type t :: %Point{
               name: atom(),
               value: any(),
               sources: name_set() | function(),
               outputs: name_set(),
               formula: nil | function(),
               type: nil | :state | :target | :view | :action
             }

  def state(name, value) do
    %Point{
      name: name,
      value: value,
      type: :state
    }
  end

  def target(name, sources, formula) do
    %Point{
      name: name,
      sources: MapSet.new(sources),
      formula: formula,
      type: :target
    }
  end

  def view(name, sources, formula) do
    %Point{
      name: name,
      sources: MapSet.new(sources), #not reactive
      formula: formula,
      type: :view
    }
  end

  def view(name, formula) when is_function(formula) do
    %Point{
      name: name,
      formula: fn -> formula.() end,
      type: :view
    }
  end

  def view(name, value) do
    %Point{
      name: name,
      formula: fn -> value end,
      type: :view
    }
  end

  def action(name, sources, outputs, formula) do
    %Point{
      name: name,
      sources: sources,
      outputs: outputs,
      formula: formula,
      type: :action
    }
  end

end