
defmodule Avast.Dagger do

  alias Avast.{Dagger, Action, Location, Event, State, Target, View}
  # Directed Acyclic Graph Event Repo

  defstruct location: nil,
            actions: [],
            states: %{},
            targets: %{},
            views: %{}

            # dagger receives events and converts to actions
            # actions udate states
            # targets watch states and targets, take views and update self
            # events watch states and targets, take views and emit

  def receive_event(%Event{} = event) do
    GenServer.call({:receive_event, event})
  end



  def handle_call({:receive_event, event}, _from, %Dagger{actions: actions} = state) do

    # event, handled by action, update states to targets to gen events

    new_state =
      actions
      |> Enum.filter(fn a -> Action.handles_event?(a, event) end)
      |> Enum.reduce(state, fn a, s -> perform_action(a, event, s) end)

    {:reply, :ok, state}

  end

  defp perform_action(action, event, state) do

    use_map = resolve_use_values(action.use)
    change_map = action.transform.(event, use_map)
    # apply changes to states, pass -- every target gets {new_value, old_value} map
    # each target gets {current_map, prior_map}
  end

  defp resolve_use_values(names) do
    %{}
  end

end