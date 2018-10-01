
defmodule Dagger.Instance do
  alias Dagger.Instance

  defstruct key: nil, node: nil

  @type t :: %Instance{
               key: any(),
               node: atom()
             }

  def new(key \\ nil) do
    %Instance{
      node: Node.self(),
      key: key
    }
  end

end