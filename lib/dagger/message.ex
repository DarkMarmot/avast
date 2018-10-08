defmodule Dagger.Message do
  alias Dagger.Message

  defstruct name: nil,
            value: nil,
            hops: []

  @type t :: %Message{
          name: atom(),
          value: any(),
          hops: list()
        }
end
