defmodule Meta.Saga.Test.WorkflowOne do
  use GenServer

  @moduledoc """
  Test Saga. Happy path, sending `process` command directly to saga service
  """

  #########################################################
  #   Example Saga - Happy Path                           #
  #########################################################

  alias Meta.Saga.Test.{Saga, Utility}

  @step_timeout 500
  @saga_timeout 20_000
  @initialize "initialize"
  @step1 "step1"
  @step2 "step2"
  @step3 "step3"
  @step4 "step4"
  @last_step "last_step"
  @stop "stop"

  #########################################################
  #
  #   API
  #
  #########################################################

  def start_link,
    do: GenServer.start_link(__MODULE__, [], name: name())

  def stop,
    do: GenServer.stop(name())

  def expected_history,
    do: [@initialize, @step1, @step2, @step3, @step4, @last_step, @stop]

  def exec_saga, do: GenServer.call(name(), :exec_saga, @saga_timeout)

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
  def handle_call(:exec_saga, from, state) do
    %{"id" => id} = saga = init_saga()
    {:ok, "ok"} = Saga.idle(id, saga, [])
    state1 = update_state(state, saga, [])
    metadata = [saga_id: id, saga_module: __MODULE__]
    {:noreply, %{state1|"reply_to" => from, "metadata" => metadata}, @step_timeout}
  end

  #########################################################
  #   Cast callbacks
  #########################################################

  @impl GenServer
  def handle_cast({:process, id, event, saga, metadata}, state) do
    :ct.log(:info, 75, 'Process id: ~p, saga: ~p, event: ~p~n', [id, saga, event])
    case dispatch(event, saga) do
      %{"current_step" => @stop, "history" => history} ->
        %{"reply_to" => reply_to} = state
        :ct.log(:info, 75, 'Dispatched stop event; history: ~p~n', [history])
        GenServer.reply(reply_to, :lists.reverse(history))
        {:noreply, initial_state()}
      %{"current_step" => @last_step} = saga1 ->
        :ct.log(:info, 75, 'Dispatched last step; saga: ~p~n', [saga1])
        {:ok, "ok"} = Saga.process(id, "stop", metadata, saga1)
        {:noreply, state}
      saga1 ->
        :ct.log('Dispatched step ~p; saga: ~p~n', [event, saga1])
        {:ok, "ok"} = Saga.idle(id, saga1, metadata)
        state1 = update_state(state, saga1, metadata)
        {:noreply, state1, @step_timeout}
    end
  end

  #########################################################
  #   other messages callbacks
  #########################################################

  @impl GenServer
  def handle_info(:timeout, %{"saga_id" => id,
                              "current_step" => step,
                              "metadata" => metadata} = state) do
    next_step = next_step(step)
    :ct.log(:info, 75, 'Emulate next command: ~p~n', [next_step])
    {:ok, "ok"} = Saga.process(id, next_step, metadata)
    {:noreply, state}
  end

  def handle_info(_message, state) do
    {:noreply, state, @step_timeout}
  end
  #########################################################
  #
  #  Private functions
  #
  #########################################################

  defp init_saga do
    %{
      "id" => Utility.new_id(),
      "current_step" => "initialize",
      "history" => ["initialize"]
    }
  end

  defp initial_state,
    do: %{
          "saga_id" => nil,
          "current_step" => nil,
          "reply_to" => nil,
          "metadata" => nil,
    }

  defp dispatch({current_step, _data} = event, saga),
    do: dispatch(current_step, event, saga)

  defp dispatch(event, saga),
    do: dispatch(event, event, saga)

  defp dispatch(current_step, event, saga) do
    case validate_step(current_step, saga) do
      :valid ->
        update_step(event, saga)
      :invalid ->
        saga
    end
  end

  defp update_step(current_step, %{"history" => history} = saga) do
    %{saga|
      "current_step" => current_step,
      "history" => [current_step | history]}
  end

  defp validate_step(@step1, %{"current_step" => @initialize}),
    do: :valid

  defp validate_step(@step2, %{"current_step" => @step1}),
      do: :valid

  defp validate_step(@step3, %{"current_step" => @step2}),
    do: :valid

  defp validate_step(@step4, %{"current_step" => @step3}),
    do: :valid

  defp validate_step(@last_step, %{"current_step" => @step4}),
    do: :valid

  defp validate_step(@stop, %{"current_step" => @last_step}),
    do: :valid

  defp validate_step(_step, _state), do: :invalid

  defp next_step(@initialize), do: @step1
  defp next_step(@step1), do: @step2
  defp next_step(@step2), do: @step3
  defp next_step(@step3), do: @step4
  defp next_step(@step4), do: @last_step
  defp next_step(@last_step), do: @stop

  defp update_state(state, %{"id" => id, "current_step" => step}, metadata),
    do: %{state|"saga_id" => id, "current_step" => step, "metadata" => metadata}

  defp name, do: {:global, __MODULE__}

end
