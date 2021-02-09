defmodule Meta.Saga.Client.Processor do

  alias Wizard.Client

  #########################################################
  #
  #   API
  #
  #########################################################

  def execute({id, state,  event, owner}, metadata) do
    {id, state, event, metadata, owner}
    |> args()
    |> Client.exec()
  end

  #########################################################
  #
  #  Private functions
  #
  #########################################################

  defp uri(service), do: "mq://#{service}"

  #--------------------------------------------------------

  defp args({id, state, event, metadata, owner}) do
    [
      to: uri(owner),
      payload: payload(id, state, event),
      metadata: metadata
    ]
  end

  #--------------------------------------------------------

  defp payload(id, state, event) do
    %{
      "id" => id,
      "state" => state,
      "event" => event
    }
  end

end
