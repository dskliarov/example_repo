defmodule Meta.Saga.Test.WorkflowIdle do
  use GenServer

  @moduledoc """
  Test Saga. Happy path, sending `process` command directly to saga service
  """

  #########################################################
  #   Example Saga - Happy Path                           #
  #########################################################

  alias Meta.Saga.Test.{Saga, Utility}

  @idle_timeout 1000
  @process_timeout 500
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

    def exec_saga, do: GenServer.call(name(), :idle_saga)

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
  def logg(str, data) do
    File.write("/tmp/bb.log", :erlang.iolist_to_binary(:io_lib.format(str ++ '~n', data)), [:append])
  end

  @impl GenServer
  def handle_call(:idle_saga, from, state) do
    %{"id" => id} = saga = init_saga()
    {:ok, "ok"} = Saga.idle(id, saga, [], 
      [idle_timeout: @idle_timeout, process_timeout: @process_timeout, retry_counter: @retry_counter])
    metadata = [saga_id: id, saga_module: __MODULE__]
    logg('run workflow idle id ~p saga ~p', [id, saga])
    {:noreply, %{state|"reply_to" => from, "metadata" => metadata}}
  end

  #########################################################
  #   Cast callbacks
  #########################################################

  @impl GenServer
  def handle_cast({:process, id, event, saga, metadata}, %{"reply_to" => reply_to} = state) do
    logg('Process id: ~p, saga: ~p, event: ~p~n', [id, saga, event])
    :ct.log(:info, 75, 'Process id: ~p, saga: ~p, event: ~p~n', [id, saga, event])
    case dispatch(event, saga) do
      {:stop, %{"idle_timeout" => idle, "process_timeout" => process} = new_saga} ->
        :ct.log(:info, 75, 'Dispatched stop event; idle_timeout: ~p process_timeout~n', [idle, process])
        GenServer.reply(reply_to, [{"idle_timeout", idle}, {"process_timeout", process}])
        {:ok, "ok"} = Saga.process(id, "stop", metadata, new_saga)
        {:noreply, initial_state()}
      {:process, %{"idle_timeout" => idle} = new_saga} ->
        :ct.log(:info, 75, 'Dispatched idle timeout ~p; saga: ~p~n', [idle, new_saga])
        {:ok, "ok"} = Saga.process(id, @some_event, metadata, new_saga)
        {:noreply, state}
      {_, saga1} ->
        :ct.log('Dispatched next timeout ~p; saga: ~p~n', [event, saga1])
        {:noreply, state}
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
      "start_time" => now(),
      "idle_timeout" => nil,
      "process_timeout" => nil,
      "process_timeout_counter" => @retry_counter,
    }
  end

  defp initial_state,
       do: %{
         "saga_id" => nil,
         "reply_to" => nil,
         "metadata" => nil,
       }

  defp dispatch("idle_timeout", %{"idle_timeout" => nil, "start_time" => start} = saga) do
    time_now = now()
    {:process, %{saga | "idle_timeout" => DateTime.diff(time_now - start, :millisecond), "start_time" => time_now}}
  end

  defp dispatch("process_timeout", %{"start_time" => start, "process_timeout_counter" => counter} = saga) when counter > 1 do
    {:next_process, %{saga | "process_timeout" => DateTime.diff(now() - start, :millisecond), "process_timeout_counter" => counter - 1}}
  end

  defp dispatch("process_timeout", %{"process_timeout" => nil, "start_time" => start} = saga) do
    {:stop, %{saga | "process_timeout" => DateTime.diff(now() - start, :millisecond)}}
  end

  defp dispatch(event, saga) do
    :ct.log(:info, 75, 'dispatch unexpected event : ~p, saga: ~p~n', [event, saga])
    {:ok, saga}
  end
  
  def now do
    {:ok, timestamp} = DateTime.now("Etc/UTC")
    timestamp
  end


  defp name, do: {:global, __MODULE__}

end
