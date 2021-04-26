defmodule Meta.Saga.Test.WorkflowIdle do
  use GenServer

  @moduledoc """
  Test Saga. Happy path, sending `idle` waiting idle timeout and send process after that  
  """

  #########################################################
  #   Example Saga - Happy Path                           #
  #########################################################

  alias Meta.Saga.Test.{Saga, Utility}

  @idle_timeout 1000
  @process_timeout 1000
  @retry_counter 3
  @some_event "some_event"

  #########################################################
  #
  #   API
  #
  #########################################################

  def start_link,
      do: GenServer.start_link(__MODULE__, [], name: name())

  def stop,
      do: GenServer.stop(name())

  def exec_saga, do: GenServer.call(name(), :idle_saga, 20_000)

  def process(id, event, saga, metadata) do
    GenServer.cast(name(), {:process, id, event, saga, metadata})
  end

  #########################################################
  #
  #   Callbacks
  #
  #########################################################

  @impl GenServer
  def init(_options) do
    state = initial_state()
    :ct.log(:info, 75, 'Init saga ~p~n', [state])
    {:ok, state}
  end

  #########################################################
  #   Call callbacks
  #########################################################
  @impl GenServer
  def handle_call(:idle_saga, from, state) do
    %{"id" => id} = saga = init_saga()
    :ok = do_idle(1, id, saga, 30_000)
    :ok = do_idle(1, id, saga, @idle_timeout)
    {:noreply, clean_state(%{state | "reply_to" => from, "metadata" => []})}
  end

  #########################################################
  #   Cast callbacks
  #########################################################

  @impl GenServer
  def handle_cast({:process, id, event, saga, metadata}, %{"reply_to" => reply_to} = state) do
    :ct.log(:info, 75, 'Process id: ~p, saga: ~p, event: ~p~n', [id, saga, event])
    case dispatch(event, state) do
      {:stop, %{"idle_timeout" => idle, "process_timeout" => process}} ->
        :ct.log(:info, 75, 'Dispatched stop event; idle_timeout: ~p process_timeout ~p~n', [idle, process])
        GenServer.reply(reply_to, {:ok, [{"idle_timeout", idle}, {"process_timeout", process}]})
        {:ok, "ok"} = Saga.process(id, "stop", metadata, saga)
        {:noreply, clean_state(state)}
      {:process, %{"idle_timeout" => idle} = new_state} ->
        :ct.log(:info, 75, 'Dispatched idle timeout ~p; saga: ~p~n', [idle, new_state])
        :ok = do_idle(5, id, saga, @idle_timeout)
        {:ok, "ok"} = Saga.process(id, @some_event, metadata, saga)
        {:noreply, new_state}
      {_resp, new_state} ->
        :ct.log('Dispatched any timeout ~p; saga: ~p~n', [event, new_state])
        {:noreply, new_state}
    end
  end

  #########################################################
  #   other messages callbacks
  #########################################################

  @impl GenServer
  #  def handle_info("idle_timeout", %{"saga_id" => id,
  #    "current_step" => step,
  #    "metadata" => metadata, } = state) do
  #    :ct.log(:info, 75, 'Got idle timeout after: ~n', [])
  #    {:ok, "ok"} = Saga.process(id, next_step, metadata)
  #    {:noreply, state}
  #  end
  #
  def handle_info(message, state) do
    :ct.log(:info, 75, 'Unexpected event: ~p~n', [message])
    {:noreply, state}
  end
  #########################################################
  #
  #  Private functions
  #
  #########################################################

  defp init_saga do
    %{
      "id" => Utility.new_id(),
      "saga_module" => __MODULE__,
    }
  end

  defp initial_state,
       do: %{
         "start_time" => nil,
         "idle_timeout" => nil,
         "process_timeout" => nil,
         "process_timeout_counter" => @retry_counter,
         "saga_id" => nil,
         "reply_to" => nil,
         "metadata" => nil,
       }

  defp clean_state(state) do
    %{
      state |
      "start_time" => now(),
      "idle_timeout" => nil,
      "process_timeout" => nil,
      "process_timeout_counter" => @retry_counter
    }
  end

  defp dispatch("idle_timeout", %{"idle_timeout" => nil, "start_time" => start} = state) do
    time_now = now()
    {:process, %{state | "idle_timeout" => (time_now - start), "start_time" => time_now}}
  end

  defp dispatch(@some_event, %{"start_time" => start, "process_timeout_counter" => counter} = state) when counter > 1 do
    {:next_process, %{state | "process_timeout" => (now() - start), "process_timeout_counter" => counter - 1}}
  end

  defp dispatch(@some_event, %{"start_time" => start} = state) do
    {:stop, %{state | "process_timeout" => (now() - start)}}
  end

  defp dispatch(_event, state) do
    {:ok, state}
  end

  def now do
    :erlang.system_time(:millisecond)
  end

  defp name, do: {:global, __MODULE__}

  defp do_idle(0, _id, _saga, _idle_timeout), do: :ok

  defp do_idle(cnt, id, saga, idle_timeout) do
    {:ok, "ok"} = Saga.idle(
      id,
      saga,
      [],
      [idle_timeout: idle_timeout, process_timeout: @process_timeout, retry_counter: @retry_counter]
    )
    do_idle(cnt - 1, id, saga, idle_timeout)
  end

end
