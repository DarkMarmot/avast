
defmodule Avast.Location do

  defstruct id: nil,
            name: nil,
            node: nil

  def new(name, id \\ nil) do
    %Location{
      id: id,
      name: name,
      node: Node.self()
    }
  end

end