
defmodule Dagger.Trigger do
  alias Dagger.Trigger

  defstruct action: nil, filter: nil, transform: nil, continue: false

  @type t :: %Trigger{
               action: atom(),
               filter: nil | function(),
               transform: nil | function(),
               continue: boolean()
             }

  def new(action, filter \\ nil, transform \\ nil, continue \\ false) do
    %Trigger{
      action: action,
      filter: filter,
      transform: transform,
      continue: continue
    }
  end

end