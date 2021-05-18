defmodule Meta.Saga.CommandHandlers.Handler do

  @moduledoc "Message handler module"

  alias Meta.Saga.Processor

  require Logger

  @saga "svc.meta.saga_v2."

  #########################################################
  #
  #   Handler
  #
  #########################################################

  def handle_message(@saga <> "idle", request, metadata),
    do: Processor.handle_event(request, "idle", metadata)

  def handle_message(@saga <> "get", %{"id" => id}, metadata),
    do: Processor.get_saga(id, metadata)

  def handle_message(@saga <> "stop", %{"id" => id,
                                        "state" => state}, metadata),
    do: Processor.stop(id, metadata, state)

  def handle_message(@saga <> "stop", %{"id" => id}, metadata),
    do: Processor.stop(id, metadata)

  def handle_message(@saga <> "process", %{"id" => id,
                                           "event" => "stop",
                                           "state" => state}, metadata) do
    Processor.stop(id, metadata, state)
  end

  def handle_message(@saga <> "process", %{"id" => id} = request, metadata) do
    event = event(request)
    Processor.handle_event(id, event, metadata)
  end

  def handle_message(@saga <> "process", request, metadata) do
    case List.keyfind(metadata, "saga_id", 0) do
      nil ->
        {:error, "Invalid request. Saga Id is not present."}
      {_, id} ->
        event = event(request)
        Processor.handle_event(id, event, metadata)
    end
  end

  def handle_message(@saga <> "process_callback", request, metadata),
    do: Logger.debug("Process result: #{inspect request}; metadata: #{inspect metadata}")

  #########################################################
  #
  #  Private functions
  #
  #########################################################

  defp event(%{"event" => event, "data" => data}),
    do: {event, data}

  defp event(%{"event" => event}), do: event
  defp event(event), do: event

end
