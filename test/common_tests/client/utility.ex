defmodule Meta.Saga.Test.Utility do

  @moduledoc false

  def new_id do
    length = 15
    length
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64
    |> binary_part(0, length)
  end
end
