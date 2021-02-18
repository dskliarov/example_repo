defmodule Meta.Saga.Client.Core do

  alias Wizard.Client

  @core "svc.meta.core."
  @entity_type "saga"

  #########################################################
  #
  #   API
  #
  #########################################################

  def write(id, data, metadata) do
    {id, data, metadata}
    |> write_args()
    |> Client.exec()
    |> output()
  end

  def read(id, metadata) do
    {id, metadata}
    |> read_args()
    |> Client.exec()
    |> output()
  end

  #########################################################
  #
  #  Private functions
  #
  #########################################################

  defp output(value), do: value

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

  defp write_args({id, data, metadata}) do
    [
      to: uri("write"),
      payload: write_payload(id, data),
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

  defp write_payload(id, data) do
    %{
          "entity_id" => id,
          "entity_type" => @entity_type,
          "payload" => data
    }
  end

end
