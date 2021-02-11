defmodule Meta.Saga.Test.WorkflowOne do
  use GenServer

  alias Meta.Saga.Test.{Saga, Utility}

  @step_timeout 1000
  @initialize "initialize"
  @step1 "step1"
  @step2 "step2"
  @step3 "step3"
  @step4 "step4"
  @last_step "last_step"

  #########################################################
  #
  #   API
  #
  #########################################################

  def start_link(),
    do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def stop(),
    do: GenServer.stop(__MODULE__)

  def expected_history(),
    do: [@initialize, @step1, @step2, @step3, @step4, @last_step]

  def exec_saga(), do: GenServer.call(__MODULE__, :exec_saga)

  def process(event, saga, metadata) do
    GenServer.cast(__MODULE__, {:process, event, saga, metadata})
  end

  #########################################################
  #
  #   Callbacks
  #
  #########################################################

  @impl GenServer
  def init(_options),
    do: {:ok, initial_state()}

  #########################################################
  #   Call callbacks
  #########################################################

  @impl GenServer
  def handle_call(:exec_saga, from, state) do
    %{"id" => id} = saga = init_saga()
    Saga.idle(id, saga, [])
    state1 = update_state(state, saga, [])
    {:noreply, %{state1|"reply_to" => from} , @step_timeout}
  end

  #########################################################
  #   Cast callbacks
  #########################################################

  @impl GenServer
  def handle_cast({{:process, event, %{"id" => id, "state" => saga}, metadata}}, state) do
    case dispatch(event, saga) do
      %{"current_step" => @last_step, "history" => history} ->
        %{"reply_to" => reply_to} = state
        GenServer.reply(reply_to, history)
        {:noreply, initial_state()}
      saga1 ->
        Saga.idle(id, saga, metadata)
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
    Saga.process(id, next_step, metadata)
    {:noreply, state}
  end
  #########################################################
  #
  #  Private functions
  #
  #########################################################

  defp init_saga() do
    %{
      "id" => Utility.new_id(),
      "current_step" => "initialize",
      "history" => []
    }
  end

  defp initial_state(),
    do: %{
          "saga_id" => nil,
          "current_step" => nil,
          "reply_to" => nil,
          "metadata" => nil
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
      "history" => [history] ++ [current_step]}
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


  defp validate_step(_step, _state), do: :invalid

  defp next_step(@initialize), do: @step1
  defp next_step(@step1), do: @step2
  defp next_step(@step2), do: @step3
  defp next_step(@step3), do: @step4
  defp next_step(@step4), do: @last_step

  defp update_state(state, %{"id" => id, "current_step" => step}, metadata),
    do: %{state|"saga_id" => id, "current_step" => step, "metadata" => metadata}

end
