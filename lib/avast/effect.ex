
defmodule Avast.Effect do

  @type t :: %Effect{
                state_name: String.t() | nil,
                transform: function() | nil
             }

  defstruct state_name: nil,
            transform: nil



end
