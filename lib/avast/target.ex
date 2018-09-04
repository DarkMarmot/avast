
defmodule Avast.Target do

  # Directed Acyclic Graph Event Repo
  defstruct dagger: nil,
            name: nil,
            value: nil,
            ready: false,
            views: nil,
            states: nil,
            targets: nil,
            current: nil

            # after state and/or target change, grab views, states, targets, call transform


end