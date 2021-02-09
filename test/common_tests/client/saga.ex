defmodule Meta.Saga.Test.Saga do

  alias Wizard.Client

  @owner "svc.meta.test_saga"
  @saga "svc.meta.saga2"
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
    |> args(metadata)
    |> Client.exec()
  end

  def process(id, event, metadata) do
    :process
    |> payload(id, event)
    |> exec(metadata)
  end

  def process(id, event, metadata) do
    process(id, event, nil, metadata)
  end

  def process(id, event, data, metadata) do
    :process
    |> payload(id, event, data)
    |> exec(metadata)
  end

  def idle_timeout, do: @idle_timeout

  def process_timeout, do: @process_timeout

  #########################################################
  #
  #  Private functions
  #
  #########################################################

  defp exec(payload, metadata) do
    payload
    |> args(metadata)
    |> Client.exec()
  end

  defp args(payload, metadata) do
    [
      to: "rpc://" <> @saga,
      payload: payload,
      metadata: metadata
    ]
  end

  defp payload(:idle, id, saga) do
    %{
      "id" => id,
      "owner" => @owner,
      "state" => %{
        "state" => Map.merge(saga, options())
      }
    }
  end

  defp payload(:process, id, event, nil) do
    %{
      "id" => id,
      "event" => event
    }
  end

  defp payload(:process, id, event, data) do
    %{
      "id" => id,
      "event" => event,
      "data" => data
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
