defmodule Meta.Saga.Processor do

  alias DistributedLib.Processor.MessageHandler
  alias Meta.Saga.Cron
  alias Meta.Saga.Client.{Core, Processor}

  @behaviour MessageHandler

  # Default values
  @retry_counter 3
  @process_timeout 10_000
  @idle_timeout 300_000

  #########################################################
  #
  #  API
  #
  #########################################################

  def handle_event(data, event, metadata \\ [])
  def handle_event(%{"id" => id} = data, :idle, metadata) do
    saga = payload(data)
    DistributedLib.process(id, {saga, :idle, metadata}, __MODULE__)
  end

  def handle_event(id, event, metadata) do
    with {:ok, saga} <- get_saga(id),
      do: DistributedLib.process(id, {saga, event, metadata}, __MODULE__)
  end

  def stop(id, metadata),
    do: handle_event(id, :stop, metadata)

  def get_saga(id, metadata \\ []) do
    with {:ok, {_id, saga}} <- CoreClient.read(id, metadata) do
      {:ok, saga}
      else
        {:ok, []} ->
          {:error, :not_found}
        error ->
          error
    end
  end

  @impl MessageHandler
  def handle(id, {%{"owner" => owner} = state, event, metadata}, _opts) do
    case dispatch_event(state, event) do
      {:error, state1} ->
        Processor.execute({id, state1, :error, owner}, metadata)
      {:execute_process, {state1, current_event, process_timeout}} ->
        Processor.execute({id, state1, current_event, owner}, metadata)
        Cron.add_execute_timeout(id, process_timeout)
      {:idle, state1, idle_timeout} ->
        Core.write(id, state1, metadata)
        Cron.add_idle_timeout(id, idle_timeout)
      {:queue, state1} ->
        Core.write(id, state1, metadata)
      {:stop, state1} ->
        Core.write(id, state1, metadata)
      {:ignore, _state} ->
        :ok
    end
  end

  #########################################################
  #
  #  Private functions
  #
  #########################################################

  defp dispatch_event(state, :stop) do
    state = %{state|"process" => "stop"}
    {:stop, state}
  end

  defp dispatch_event(%{"process" => "stop"} = state, _event) do
    {:ignore, state}
  end

  defp dispatch_event(%{"process" => {_current_event, 0}} = state,
    :processor_timeout) do
    {:error, state}
  end

  defp dispatch_event(%{"process" => {
                        current_event,
                        retry_counter
                        }} = state, :processor_timeout) do
    state = %{state|"process" => {current_event, retry_counter - 1}}
    process_timeout = Map.get(state, "process_timeout", @process_timeout)
    {:execute_process, {state, current_event, process_timeout}}
  end

  defp dispatch_event(%{"events_queue" => queue} = state, :idle) do
    case :queue.out(queue) do
      {:empty, _queue1} ->
        idle_timeout = Map.get(state, "idle_timeout", @idle_timeout)
        {:idle, state, idle_timeout}
      {{:value, event}, queue1} ->
        retry_counter = Map.get(state, "retry_counter", @retry_counter)
        process_timeout = Map.get(state, "process_timeout", @process_timeout)
        state = %{state|"process" =>
                   {event, retry_counter},
                  "events_queue" => queue1}
        {:execute_process, {state, event, process_timeout}}
    end
  end

  defp dispatch_event(%{"process" => ""} = state, event) do
    retry_counter = Map.get(state, "retry_counter", @retry_counter)
    process_timeout = Map.get(state, "process_timeout", @process_timeout)
    state = %{state|"process" => {event, retry_counter}}
    {:execute_process, {state, event, process_timeout}}
  end

  defp dispatch_event(%{"events_queue" => queue} = state, event) do
    state = %{state|"events_queue" => :queue.in(event, queue)}
    {:queue, state}
  end

  defp payload(%{"state" => state, "owner" => owner}) do
    %{
      "state" => state,
      "owner" => owner,
      "process" => "",
      "events_queue" => :queue.new()
    }
  end
end
