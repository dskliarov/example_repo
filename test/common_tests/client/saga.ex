defmodule Meta.Saga.Test.Saga do

  alias Wizard.Client

  @owner "svc.meta.test_saga.response"
  @saga "svc.meta.saga2"
  @idle ".idle"
  @process ".process"
  @idle_timeout 3_000
  @process_timeout 2_000
  @retry_counter 3

  #########################################################
  #
  #   API
  #
  #########################################################

  def idle(id, saga, metadata) do
    :idle
    |> payload(id, saga)
    |> exec(@idle, metadata)
  end

  def process(id, event, metadata) do
    :process
    |> payload(id, event)
    |> exec(@process, metadata)
  end

  def idle_timeout, do: @idle_timeout

  def process_timeout, do: @process_timeout

  #########################################################
  #
  #  Private functions
  #
  #########################################################

  defp exec(payload, action, metadata) do
    payload
    |> args(action, metadata)
    |> Client.exec()
    |> execution_result_log(payload, action)
  end

  defp execution_result_log(result, payload, action) do
    :ct.log('Send action: ~p for saga: ~p with result ~p~n',
      [action, payload, result])
  end

  defp args(payload, action, metadata) do
    [
      to: "rpc://" <> @saga <> action,
      payload: payload,
      metadata: metadata
    ]
  end

  defp payload(:idle, id, saga) do
    %{
      "id" => id,
      "owner" => @owner,
      "state" => Map.merge(saga, options())
    }
  end

  defp payload(:process, id, event) do
    %{
      "id" => id,
      "event" => event
    }
  end

  defp options() do
    %{"options" => %{
      "idle_timeout" => @idle_timeout,
      "process_timeout" => @process_timeout,
      "retry_counter" => @retry_counter
    }}
  end

end
