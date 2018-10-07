defmodule Dagger.Point do
  alias Dagger.Point

  defstruct name: nil,
            value: nil,
            sources: MapSet.new(),
            outputs: MapSet.new(),
            formula: nil,
            active: false,
            ephemeral: false,
            type: nil

  # triggers are a list of functions mapped to actions -- take event and return boolean

  # points can be type:
  # action  --  has sources and outputs and formula and ephemeral
  # state   --  no sources, no formula
  # target  --  has sources and formula
  # view    --  formula only
  # event   --  has sources and formula -- but ephemeral

  # trigger -- map/filter to action

  @type name_set :: MapSet.t(atom)

  @type t :: %Point{
          name: atom(),
          value: any(),
          sources: name_set(),
          outputs: name_set(),
          formula: nil | function(),
          active: boolean(),
          ephemeral: boolean(),
          type: nil | :state | :target | :view | :action | :event
        }

  # todo remove value -- init via update only
  def state(name) when is_atom(name) do
    %Point{
      name: name,
      type: :state
    }
  end

  def event(name, formula, sources)
      when is_atom(name) and is_function(formula) and is_list(sources) do
    %Point{
      name: name,
      sources: MapSet.new(sources),
      formula: formula,
      type: :event,
      ephemeral: true
    }
  end

  def target(name, formula, sources)
      when is_atom(name) and is_function(formula) and is_list(sources) do
    %Point{
      name: name,
      sources: MapSet.new(sources),
      formula: formula,
      type: :target
    }
  end

  def view(name, formula)
      when is_atom(name) and is_function(formula) do
    %Point{
      name: name,
      formula: formula,
      type: :view,
      active: true
    }
  end

  def view(name, value)
      when is_atom(name) do
    %Point{
      name: name,
      formula: fn -> value end,
      type: :view,
      active: true
    }
  end

  def action(name, formula, sources)
      when is_atom(name) and is_function(formula) do
    %Point{
      name: name,
      sources: MapSet.new(sources),
      formula: formula,
      type: :action,
      ephemeral: true
    }
  end
end
