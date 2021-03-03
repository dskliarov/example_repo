defmodule Meta.Saga.Test.Client.Endpoint do
  use Wizard.Endpoint, service: :test_saga, type: :svc, namespace: :meta

  @moduledoc false

  alias Meta.Saga.Test.Client, as: Command

  command("response", Command.Handler)
  command("remote_service_response_emulator", Command.Handler)
end
