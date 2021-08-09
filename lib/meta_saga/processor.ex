defmodule Meta.Saga.Processor do

  @moduledoc """
  Saga event processor
  """

  require Logger

  alias DistributedLib.Processor.MessageHandler
  alias Meta.Saga.{Aeon.Entities, Aeon.Services, Cron}
  alias Wizard.ResourceLocator

  @behaviour MessageHandler

  # Default values
  @retry_counter 3
  @process_timeout 10_000
  @idle_timeout 300_000
  @event_type "saga_event_type"

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
  @type metadata :: map()
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
  {:execute_process, execute_message()} |
  {:idle, saga_payload(), timeout()} |
  {:final_error, saga_payload()}

  @type request :: map()

  #########################################################
  #
  #  API
  #
  #########################################################

  @spec handle_event(data(), event(), metadata()) :: handle_result()
  def handle_event(data, event, metadata \\ %{})
  def handle_event(%{"id" => id} = data, "idle", metadata) do
    metadata_updated =
      Map.put(metadata, @event_type, "external")
    args = {data, "idle", metadata_updated}
    DistributedLib.process(id, args, __MODULE__)
  end

  def handle_event(id, event, metadata) do
    metadata_updated =
      Map.put(metadata, @event_type, "external")
    args = {event, metadata_updated}
    DistributedLib.process(id, args, __MODULE__)
  end

  @spec handle_internal_event(saga_id(), event(), metadata()) :: handle_result()
  def handle_internal_event(id, event, metadata \\ %{}) do
    metadata_updated = Map.put(metadata, @event_type, "internal")
    args = {event, metadata_updated}
    DistributedLib.process(id, args, __MODULE__)
  end

  @spec stop(saga_id(), metadata()) :: handle_result()
  def stop(id, metadata),
    do: handle_event(id, "stop", metadata)

  @spec stop(saga_id(), metadata(), term()) :: handle_result()
  def stop(id, metadata, saga) do
    handle_event(id, {"stop", saga}, metadata)
  end

  @spec get_saga_with_owner_check(saga_id(), metadata()) :: {:ok, saga_payload} | error
  def get_saga_with_owner_check(id, metadata) do
    with %{"type" => type, "namespace" => namespace, "service" => service} <- Map.get(metadata, "call_source", nil),
         {:ok, {_id, %{"owner" => owner}}} = response <- Entities.Saga.core_read(id, metadata),
         true <- match_caller_and_owner?(type, namespace, service, owner) do
      response
    else
      nil ->
        {:error, "saga: metadata has no caller info"}
      false ->
        {:error, "saga: caller and owner missmatch"}
      error ->
        error
    end
  end

  #########################################################
  #
  #  Distributed transaction handler
  #
  #########################################################

  @impl MessageHandler
  def handle(id, {data, event, metadata}, _opts) when event in ["idle", "continue"] do
    saga = payload(data)
    process_saga(id, saga, event, metadata)
  end

  @impl MessageHandler
  def handle(id, {event, metadata}, _opts) do
    with {:ok, saga} <- Entities.Saga.core_read(id, metadata),
      do: process_saga(id, saga, event, metadata)
  end

  @spec process_saga(saga_id(), saga(), event(), metadata()) :: :ok | Services.Owner.result()
  def process_saga(id, {id, state}, event, metadata),
    do: process_saga(id, state, event, metadata)

  def process_saga(id, [state], event, metadata),
    do: process_saga(id, state, event, metadata)

  def process_saga(id, %{"owner" => owner} = saga_payload, event, metadata) do
    case dispatch_event(saga_payload, event) do
      {:final_error, saga_payload} ->
        Logger.debug("Final error handling: #{inspect saga_payload}; metadata: #{inspect metadata}")
        saga_payload1 = update_saga_error("final_process_timeout", saga_payload)
        dispatch_event(saga_payload1, "stop")
      {:execute_process, {saga_payload1, current_event, process_timeout}} ->
        %{"state" => state} = saga_payload1
        {:ok, "async_submitted"} = Services.Owner.execute(id, state, current_event, owner, metadata)
        :ok = store_saga_with_verification(id, saga_payload1, metadata, 3)
        :ok = Cron.add_execute_timeout(id, process_timeout)
      {:idle, saga_payload1, idle_timeout} ->
        switch_to_idle(id, saga_payload1, idle_timeout, metadata)
      {:queue, saga_payload1} ->
        :ok = store_saga_with_verification(id, saga_payload1, metadata, 3)
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

  defp match_caller_and_owner?(type, namespace, service, owner) do
    case ResourceLocator.parse(owner) do
      {_protocol, {^type, ^namespace, ^service, _command}} -> true
      _rest -> false
    end
  end

  defp update_saga_error(error, %{"error" => ""} = saga) do
    %{saga|"error" => error}
  end

  defp update_saga_error(error, %{"error" => error,
                                  "error_history" => error_history} = saga) do
    %{saga|"error" => error, "error_history" => [error | error_history]}
  end

  defp switch_to_idle(id, saga, idle_timeout, metadata) do
    :ok = store_saga_with_verification(id, saga, metadata, 3)
    :ok = Cron.add_idle_timeout(id, idle_timeout)
  end

  @spec finalize_saga(saga_id(), saga_payload(), uri(), event(), metadata()) :: :ok
  defp finalize_saga(id, %{"state" => state} = saga_payload, owner, "stop", metadata) do
    with :ok <- store_saga_with_verification(id, saga_payload, metadata, 3),
         :ok <- Cron.delete_timeout(id),
         {:ok, "async_submitted"} <- Services.Owner.execute(id, state, "stop", owner, metadata),
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

  # Final error. Do not retry
  defp dispatch_event(%{"process" => {_current_event, 0}} = saga_payload,
    :process_timeout) do
    {:final_error, saga_payload}
  end

  defp dispatch_event(%{"process" => {
                        current_event,
                        retry_counter
                        }} = saga_payload, :process_timeout) do
    Logger.debug("Process execution timeout. Retry counter: #{inspect retry_counter};
    current_event: #{inspect current_event}")
    retry_counter1 = retry_counter - 1
    saga_payload = %{saga_payload|"process" => {current_event, retry_counter1}}
    process_timeout = process_timeout(saga_payload)
    {:execute_process, {saga_payload, current_event, process_timeout}}
  end

  defp dispatch_event(%{"events_queue" => queue} = saga_payload, "idle") do
    case :queue.out(queue) do
      {:empty, _queue1} ->
        idle_timeout = idle_timeout(saga_payload)
        saga_payload = %{saga_payload|"process" => ""}
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

  defp dispatch_event(saga_payload, "continue") do
    retry_counter = retry_counter(saga_payload)
    process_timeout = process_timeout(saga_payload)
    saga_payload = %{saga_payload|"process" => {"continue", retry_counter}}
    {:execute_process, {saga_payload, "continue", process_timeout}}
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
      "timestamp" => 0,
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

  defp store_saga_with_verification(_id, _saga, _metadata, 0),
    do: {:error, "Error while store saga"}

  defp store_saga_with_verification(id, saga, metadata, retry_counter) do
    timestamp = :os.system_time(:millisecond)
    saga_updated = %{saga|"timestamp" => timestamp}
    with :ok <- Entities.Saga.core_write(id, saga_updated, metadata),
         {:ok, {_id, %{"timestamp" => ^timestamp}}} <- Entities.Saga.core_read(id, metadata) do
      :ok
      else
        {:ok, {_id, %{"timestamp" => actual_timestamp}}} ->
          Logger.debug("Verification of stored saga with id #{id} failed. Expected timestamp is #{timestamp},
          actual timestamp is #{actual_timestamp}")
          store_saga_with_verification(id, saga, metadata, retry_counter - 1)
        error ->
          Logger.error("Error while storing saga with id #{id}; Error: #{inspect error}")
          :timer.sleep(1000)
          store_saga_with_verification(id, saga, metadata, retry_counter - 1)
    end
  end
end
