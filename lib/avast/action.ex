
defmodule Avast.Action do

  alias Avast.Action

  @type t :: %Action{
                name: atom(),
                from: nil | atom() | [atom()], # {:cow, 2} -- the last 2 cow vals
                use: nil | atom() | [atom()],
                transform: nil | map() | function()
             }

  defstruct name: :default_action,
            from: nil,
            use: nil,
            transform: nil


  def new(name, from, transform, use \\ nil, pass \\ false) when is_atom(name) do
    %Action{
      name: name,
      from: from,
      transform: transform,
      use: use
    }
  end

  @spec handles_event?(Action.t(), Event.t()) :: boolean()
  def handles_event?(%Action{} = action, event) do

    case action do
      %Action{from: nil} -> true
      %Action{from: ev} when is_atom(ev) -> ev == event.name
      %Action{from: evs} when is_list(evs) -> event.name in evs
      _ -> false
    end

  end

end
