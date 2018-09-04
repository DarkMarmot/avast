
defmodule Avast.Event do

  defstruct source: nil,
            destination: nil,
            name: nil,
            value: nil,
            history: %{} # event source to occurence count

end
