defmodule Meta.Saga.Test.Client.Endpoint do

  use Wizard.Endpoint, service: :test_saga, type: :svc, namespace: :meta

  alias Meta.Saga.Test.Client, as: Command

  command("response", Command.Handler)
end
