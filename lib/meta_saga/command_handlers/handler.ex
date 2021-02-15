defmodule Meta.Saga.CommandHandlers.Handler do

  alias Meta.Saga.Processor

  require Logger

  @saga "svc.meta.saga2."

  #########################################################
  #
  #   Handler
  #
  #########################################################

  def handle_message(@saga <> "idle", request, metadata),
    do: Processor.handle_event(request, :idle, metadata)

  def handle_message(@saga <> "get", %{"id" => id}, metadata),
    do: Processor.get_saga(id, metadata)

  def handle_message(@saga <> "stop", %{"id" => id, "event" => "stop"}, metadata),
    do: Processor.stop(id, metadata)

  def handle_message(@saga <> "process", %{"id" => id} = request, metadata) do
    event = event(request)
    Processor.handle_event(id, event, metadata)
  end

  #########################################################
  #
  #  Private functions
  #
  #########################################################

  defp event(%{"event" => event, "data" => data}),
    do: {event, data}

  defp event(%{"event" => event}), do: event

end
