defmodule Meta.Saga.Processor do

  @moduledoc """
  Saga event processor
  """

  alias DistributedLib.Processor.MessageHandler
  alias Meta.Saga.{Aeon.Entities, Aeon.Services, Cron}

  @behaviour MessageHandler

  # Default values
  @retry_counter 3
  @process_timeout 10_000
  @idle_timeout 300_000

  #########################################################
  #
  #   Types
  #
  #########################################################

  @type error :: {:error, :not_found | term()}
  @type not_ready_list :: [atom()]
  @type handle_result :: DistributedLib.process_result() | error()
  @type saga_id :: binary()
  @type event :: binary() | {binary(), term()}
  @type metadata :: keyword()
  @type data :: map() | binary()
  @type uri :: binary()
  @type queue :: tuple()
  @type saga_payload :: map()
  @type saga :: {saga_id(), saga_payload()} | [saga_payload()] | saga_payload()
  @type distributed_message :: {saga(), event(), metadata()}
  @type execute_message :: {saga_payload(), event(), timeout()}
  @type dispatch_command ::
  {:stop, saga_payload()} |
  {:ignore, saga_payload()} |
  {:error, saga_payload()} |
  {:queue, saga_payload()} |
  {:execute_process, execute_message()} | {:idle, saga_payload(), timeout()}
  @type request :: map()

  #########################################################
  #
  #  API
  #
  #########################################################

  @spec handle_event(data(), event(), metadata()) :: handle_result()
  def handle_event(data, event, metadata \\ [])
  def handle_event(%{"id" => id} = data, "idle", metadata) do
    saga = payload(data)
    DistributedLib.process(id, {saga, "idle", metadata}, __MODULE__)
  end

  def handle_event(id, event, metadata) do
    with {:ok, saga} <- get_saga(id) do
        DistributedLib.process(id, {saga, event, metadata}, __MODULE__)
    end
  end

  @spec stop(saga_id(), keyword()) :: handle_result()
  def stop(id, metadata),
    do: handle_event(id, "stop", metadata)

  @spec stop(saga_id(), keyword(), term()) :: handle_result()
  def stop(id, metadata, saga) do
    handle_event(id, {"stop", saga}, metadata)
  end

  @spec get_saga(saga_id(), keyword()) :: {:ok, saga_payload} | error
  def get_saga(id, metadata \\ []) do
    Entities.Saga.core_get(id, metadata)
  end

  #########################################################
  #
  #  Distributed transaction handler
  #
  #########################################################

  @spec handle(saga_id(), distributed_message(), map()) :: :ok | Services.Owner.result()
  @impl MessageHandler
  def handle(id, {{id, state}, event, metadata}, opts),
    do: handle(id, {state, event, metadata}, opts)

  def handle(id, {[state], event, metadata}, opts),
    do: handle(id, {state, event, metadata}, opts)

  def handle(id, {%{"owner" => owner} = saga_payload, event, metadata}, _opts) do
    case dispatch_event(saga_payload, event) do
      {:error, %{"state" => state}} ->
        Services.Owner.execute(id, state, :error, owner, metadata)
      {:execute_process, {saga_payload1, current_event, process_timeout}} ->
        %{"state" => state} = saga_payload1
        {:ok, "ok"} = Services.Owner.execute(id, state, current_event, owner, metadata)
        {:ok, _} = Entities.Saga.core_put(id, saga_payload1, metadata)
        :ok = Cron.add_execute_timeout(id, process_timeout)
      {:idle, saga_payload1, idle_timeout} ->
        {:ok, _} = Entities.Saga.core_put(id, saga_payload1, metadata)
        :ok = Cron.add_idle_timeout(id, idle_timeout)
      {:queue, saga_payload1} ->
        {:ok, _} = Entities.Saga.core_put(id, saga_payload1, metadata)
      {:stop, saga_payload1} ->
        :ok = finalize_saga(id, saga_payload1, owner, event, metadata)
      {:ignore, _state} ->
        :ok
    end
  end

  #########################################################
  #
  #  Private functions
  #
  #########################################################

  @spec finalize_saga(saga_id(), saga_payload(), uri(), event(), keyword()) :: :ok
  defp finalize_saga(id, %{"state" => state} = saga_payload, owner, "stop", metadata) do
    with {:ok, _} <- Entities.Saga.core_put(id, saga_payload, metadata),
         :ok <- Cron.delete_timeout(id),
         {:ok, "ok"} <- Services.Owner.execute(id, state, "stop", owner, metadata),
      do: :ok
  end

  defp finalize_saga(id, saga_payload, owner, {"stop", _saga}, metadata),
    do: finalize_saga(id, saga_payload, owner, "stop", metadata)

  @spec dispatch_event(saga_payload, event) :: dispatch_command()
  defp dispatch_event(saga_payload, "stop") do
    saga_payload = %{saga_payload|"process" => "stop"}
    {:stop, saga_payload}
  end

  defp dispatch_event(saga_payload, {"stop", updated_state}) do
    saga_payload = %{saga_payload|"process" => "stop",
                     "state" => updated_state}
    {:stop, saga_payload}
  end

  defp dispatch_event(%{"process" => "stop"} = saga_payload, _event) do
    {:ignore, saga_payload}
  end

  defp dispatch_event(%{"process" => {_current_event, 0}} = saga_payload,
    :process_timeout) do
    {:error, saga_payload}
  end

  defp dispatch_event(%{"process" => {
                        current_event,
                        retry_counter
                        }} = saga_payload, :process_timeout) do
    retry_counter1 = retry_counter - 1
    saga_payload = %{saga_payload|"process" => {current_event, retry_counter1}}
    process_timeout = process_timeout(saga_payload)
    {:execute_process, {saga_payload, current_event, process_timeout}}
  end

  defp dispatch_event(%{"events_queue" => queue} = saga_payload, "idle") do
    case :queue.out(queue) do
      {:empty, _queue1} ->
        idle_timeout = idle_timeout(saga_payload)
        {:idle, saga_payload, idle_timeout}
      {{:value, event}, queue1} ->
        retry_counter = retry_counter(saga_payload)
        process_timeout = process_timeout(saga_payload)
        saga_payload = %{saga_payload|"process" =>
                   {event, retry_counter},
                  "events_queue" => queue1}
        {:execute_process, {saga_payload, event, process_timeout}}
    end
  end

  defp dispatch_event(%{"process" => ""} = saga_payload, event) do
    retry_counter = retry_counter(saga_payload)
    process_timeout = process_timeout(saga_payload)
    saga_payload = %{saga_payload|"process" => {event, retry_counter}}
    {:execute_process, {saga_payload, event, process_timeout}}
  end

  defp dispatch_event(%{"events_queue" => queue} = saga_payload, event) do
    saga_payload = %{saga_payload|"events_queue" => :queue.in(event, queue)}
    {:queue, saga_payload}
  end

  @spec payload(request()) :: saga_payload()
  defp payload(%{"state" => state, "owner" => owner}) do
    %{
      "state" => state,
      "owner" => owner,
      "process" => "",
      "error" => "",
      "error_history" => [],
      "events_queue" => :queue.new()
    }
  end

  @spec get_options(saga_payload()) :: map()
  defp get_options(saga_payload) do
    saga_payload
    |> Map.get("state", %{})
    |> Map.get("options", %{})
  end

  @spec process_timeout(saga_payload()) :: integer()
  defp process_timeout(saga_payload),
    do: get_option(saga_payload, "process_timeout", @process_timeout)

  @spec idle_timeout(saga_payload()) :: integer()
  defp idle_timeout(saga_payload),
    do: get_option(saga_payload, "idle_timeout", @idle_timeout)

  @spec retry_counter(saga_payload()) :: integer()
  defp retry_counter(saga_payload),
    do: get_option(saga_payload, "retry_counter", @retry_counter)

  @spec get_option(saga_payload(), binary(), term()) :: term
  defp get_option(saga_payload, setting, default) do
    saga_payload
    |> get_options()
    |> Map.get(setting, default)
  end
end
