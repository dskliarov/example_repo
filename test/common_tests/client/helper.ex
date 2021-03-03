defmodule Meta.Saga.Test.Client.Helper do

  @moduledoc false

  alias Wizard.Client

  @to "rpc://svc.meta.test_saga.remote_service_response_emulator"
  @saga "rpc://svc.meta.saga2.process"

  def emulate(value, metadata) do
    [
      to: @to,
      payload: value,
      callback: @saga,
      metadata: metadata
    ]
    |> Client.exec()
  end
end
