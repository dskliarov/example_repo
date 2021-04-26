defmodule Meta.Saga.Test.Client.Handler do

  require Logger

  @saga "svc.meta.test_saga."

  @moduledoc false

  #########################################################
  #
  #   Handler
  #
  #########################################################

  def handle_message(
        @saga <> "response",
        %{
          "id" => id,
          "event" => event,
          "state" => state
        },
        metadata
      ) do
    saga_module = get_saga_module(metadata, state)
    case event do
      %{"next_step" => next_step} ->
        saga_module.process(id, next_step, state, metadata)
      event ->
        saga_module.process(id, event, state, metadata)
    end
  end

  def handle_message(@saga <> "remote_service_response_emulator", request, _metadata) do
    {:ok, request}
  end

  defp get_saga_module(metadata, state) do
    case Keyword.get(metadata, :saga_module) do
      nil ->
        String.to_existing_atom(Map.get(state, "saga_module"))
      saga_module -> saga_module
    end
  end

  #########################################################
  #
  #  Private functions
  #
  #########################################################

end
