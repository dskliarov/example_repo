defmodule Meta.Saga.Processor do

  alias Meta.Saga.Cron
  alias Meta.Saga.Client.{Core, Processor}
  alias DistributedLib.Processor.MessageHandler

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

  def handle_event(payload, event, metadata \\ [])
  def handle_event(payload, :idle, metadata) do
    %{"id" => id,
      "state" => state,
      "owner" => owner} = payload
    DistributedLib.process(id, {state, :idle, owner, metadata}, __MODULE__)
  end

  def handle_event(id, event, metadata) do
    with {:ok, {state, owner}} <- get_saga(id),
      do: DistributedLib.process(id, {state, event, owner, metadata}, __MODULE__)
  end

  def stop(id, metadata),
    do: handle_event(id, :stop, metadata)

  def get_saga(id, metadata \\ []) do
    with {:ok, {_id,
                %{"state" => state,
                  "owner" => owner}}
         } <- CoreClient.read(id, metadata) do
      {:ok, {state, owner}}
      else
        {:ok, []} ->
          {:error, :not_found}
        error ->
          error
    end
  end

  @impl MessageHandler
  def handle(id, {state, event, owner, metadata}, _opts) do
    case dispatch_event(state, event) do
      {:error, state} ->
        Processor.execute({id, state, :error, owner}, metadata)
      {:execute_process, {state1, current_event, process_timeout}} ->
        Processor.execute({id, state1, current_event, owner}, metadata)
        Cron.add_execute_timeout(id, process_timeout)
      {:idle, state, idle_timeout} ->
        Core.write({id, state, owner}, metadata)
        Cron.add_idle_timeout(id, idle_timeout)
      {:queue, state1} ->
        Core.write({id, state1, owner}, metadata)
      {:stop, state1} ->
        Core.write({id, state1, owner}, metadata)
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

end
