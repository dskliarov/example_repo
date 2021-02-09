defmodule Meta.Saga.Client.Core do

  alias Wizard.Client

  @core "svc.meta.core"
  @entity_type "saga"

  #########################################################
  #
  #   API
  #
  #########################################################

  def write({id, state,  owner}, metadata) do
    {id, state, owner, metadata}
    |> write_args()
    |> Client.exec()
  end

  def read(id) do
    id
    |> read_args()
    |> Client.exec()
  end

  #########################################################
  #
  #  Private functions
  #
  #########################################################

  defp uri(action) do
    resource = @core <> action
    "rpc://#{resource}"
  end

  #--------------------------------------------------------

  defp read_args({id, metadata}) do
    [
      to: uri("read"),
      payload: read_payload(id),
      metadata: metadata
    ]
  end

  defp write_args({id, state, owner, metadata}) do
    [
      to: uri("write"),
      payload: write_payload(id, state, owner),
      metadata: metadata
    ]
  end

  #--------------------------------------------------------

  defp read_payload(id) do
    %{
      index: %{
        "index_name" => @entity_type,
        "index_value" => id
      },
      entity_type: @entity_type
    }
  end

  defp write_payload(id, state, owner) do
    %{
          "entity_id" => id,
          "entity_type" => @entity_type,
          "payload" => %{
            "state" => state,
            "owner" => owner,
            "process" => "",
            "events_queue" => :queue.new()
          }
    }
  end

end
