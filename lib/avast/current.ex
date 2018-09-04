
defmodule Avast.Current do

  # Directed Acyclic Graph Event Repo
  defstruct views: nil,
            states: nil,
            value: nil,
            ready: false,
            current: nil

end