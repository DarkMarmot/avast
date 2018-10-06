defmodule Dagger.Event do
  alias Dagger.Event

  defstruct name: nil,
            value: nil,
            hops: []

  @type t :: %Event{
          name: atom(),
          value: any(),
          hops: list()
        }
end
