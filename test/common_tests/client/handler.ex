defmodule Meta.Saga.Test.Client.Handler do

  require Logger

  @saga "svc.meta.test_saga."

  #########################################################
  #
  #   Handler
  #
  #########################################################

  def handle_message(@saga <> "response", %{"id" => id,
                                            "event" => event,
                                            "state" => state}, metadata) do
    saga_module = Keyword.get(metadata, :saga_module)
    case event do
      %{"next_step" => next_step} ->
        saga_module.process(id, next_step, state, metadata)
      event ->
        saga_module.process(id, event, state, metadata)
    end
  end

  def handle_message(@saga <> "remote_service_response_emulator", request , _metadata) do
    {:ok, request}
  end

  #########################################################
  #
  #  Private functions
  #
  #########################################################

end
